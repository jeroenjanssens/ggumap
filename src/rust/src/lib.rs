//! R bindings for Apple's Rust implementation of UMAP (`apple/embedding-atlas`).
//!
//! The computation runs on a background thread inside a dedicated rayon pool.
//! The R main thread stays in a loop that relays progress to an R callback and
//! polls for user interrupts. R's API is only ever touched from the main thread.

use std::ffi::{c_int, c_void};
use std::panic::{self, AssertUnwindSafe};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::mpsc;
use std::sync::Arc;
use std::thread;
use std::time::Duration;

use extendr_api::prelude::*;
use extendr_api::{Error, Result};
use ndarray::Array2;
use umap::{Init, Optimizer, Umap, UmapResult};

extern "C" {
    fn R_ToplevelExec(fun: Option<unsafe extern "C" fn(*mut c_void)>, data: *mut c_void) -> c_int;
    fn R_CheckUserInterrupt();
}

unsafe extern "C" fn check_interrupt_fn(_: *mut c_void) {
    R_CheckUserInterrupt();
}

/// `true` when the user pressed Ctrl-C / Esc. Safe: never longjmps out of Rust.
fn user_interrupted() -> bool {
    // SAFETY: R_ToplevelExec catches the longjmp raised by R_CheckUserInterrupt.
    unsafe { R_ToplevelExec(Some(check_interrupt_fn), std::ptr::null_mut()) == 0 }
}

/// Panic payload used to abort the computation after an interrupt.
struct Cancelled;

enum Msg {
    Progress(f32, String),
    Done(std::result::Result<UmapResult, String>),
}

/// Parameters, extracted from the R list on the main thread.
#[derive(Clone)]
struct Params {
    n_components: usize,
    n_neighbors: usize,
    min_dist: f32,
    spread: f32,
    metric: String,
    n_epochs: Option<usize>,
    learning_rate: f32,
    negative_sample_rate: usize,
    repulsion_strength: f32,
    local_connectivity: f32,
    set_op_mix_ratio: f32,
    seed: Option<u64>,
    init: Init,
    compatibility_layout: bool,
    optimizer: Option<Optimizer>,
    a: Option<f32>,
    b: Option<f32>,
    disconnection_distance: Option<f32>,
    n_threads: usize,
}

fn get(params: &List, name: &str) -> Result<Option<Robj>> {
    for (key, value) in params.iter() {
        if key == name {
            return Ok(if value.is_null() { None } else { Some(value) });
        }
    }
    Ok(None)
}

fn real(params: &List, name: &str) -> Result<Option<f64>> {
    match get(params, name)? {
        None => Ok(None),
        Some(v) => v
            .as_real()
            .or_else(|| v.as_integer().map(f64::from))
            .map(Some)
            .ok_or_else(|| Error::Other(format!("`{name}` must be a number"))),
    }
}

fn req_real(params: &List, name: &str) -> Result<f64> {
    real(params, name)?.ok_or_else(|| Error::Other(format!("`{name}` is required")))
}

fn string(params: &List, name: &str) -> Result<Option<String>> {
    match get(params, name)? {
        None => Ok(None),
        Some(v) => v
            .as_str()
            .map(|s| Some(s.to_string()))
            .ok_or_else(|| Error::Other(format!("`{name}` must be a string"))),
    }
}

fn parse_params(params: &List) -> Result<Params> {
    let count = |name: &str| -> Result<usize> {
        let v = req_real(params, name)?;
        if !v.is_finite() || v < 0.0 || v.fract() != 0.0 {
            return Err(Error::Other(format!(
                "`{name}` must be a non-negative whole number"
            )));
        }
        Ok(v as usize)
    };
    let init: Init = string(params, "init")?
        .unwrap_or_else(|| "auto".to_string())
        .parse()
        .map_err(Error::Other)?;
    let optimizer = match string(params, "optimizer")? {
        None => None,
        Some(s) => Some(s.parse::<Optimizer>().map_err(Error::Other)?),
    };
    let seed = match real(params, "seed")? {
        None => None,
        Some(s) if s.is_finite() && s >= 0.0 => Some(s as u64),
        Some(_) => return Err(Error::Other("`seed` must be a non-negative number".into())),
    };
    Ok(Params {
        n_components: count("n_components")?,
        n_neighbors: count("n_neighbors")?,
        min_dist: req_real(params, "min_dist")? as f32,
        spread: req_real(params, "spread")? as f32,
        metric: string(params, "metric")?.unwrap_or_else(|| "euclidean".to_string()),
        n_epochs: match real(params, "n_epochs")? {
            None => None,
            Some(_) => Some(count("n_epochs")?),
        },
        learning_rate: req_real(params, "learning_rate")? as f32,
        negative_sample_rate: count("negative_sample_rate")?,
        repulsion_strength: req_real(params, "repulsion_strength")? as f32,
        local_connectivity: req_real(params, "local_connectivity")? as f32,
        set_op_mix_ratio: req_real(params, "set_op_mix_ratio")? as f32,
        seed,
        init,
        compatibility_layout: get(params, "compatibility_layout")?
            .and_then(|v| v.as_bool())
            .unwrap_or(true),
        optimizer,
        a: real(params, "a")?.map(|x| x as f32),
        b: real(params, "b")?.map(|x| x as f32),
        disconnection_distance: real(params, "disconnection_distance")?.map(|x| x as f32),
        n_threads: count("n_threads")?.max(1),
    })
}

fn run_umap(
    data: Array2<f32>,
    p: Params,
    tx: mpsc::Sender<Msg>,
    cancel: Arc<AtomicBool>,
) -> std::result::Result<UmapResult, String> {
    let pool = rayon::ThreadPoolBuilder::new()
        .num_threads(p.n_threads)
        .build()
        .map_err(|e| format!("could not create a thread pool: {e}"))?;
    pool.install(move || {
        let mut builder = Umap::builder(&data)
            .n_components(p.n_components)
            .n_neighbors(p.n_neighbors)
            .min_dist(p.min_dist)
            .spread(p.spread)
            .metric(&p.metric)
            .learning_rate(p.learning_rate)
            .negative_sample_rate(p.negative_sample_rate)
            .repulsion_strength(p.repulsion_strength)
            .local_connectivity(p.local_connectivity)
            .set_op_mix_ratio(p.set_op_mix_ratio)
            .init_method(p.init.clone())
            .compatibility_layout(p.compatibility_layout)
            .verbose(false);
        if let Some(n) = p.n_epochs {
            builder = builder.n_epochs(n);
        }
        if let Some(seed) = p.seed {
            builder = builder.random_state(seed);
        }
        if let Some(o) = p.optimizer {
            builder = builder.optimizer(o);
        }
        if let Some(a) = p.a {
            builder = builder.a(a);
        }
        if let Some(b) = p.b {
            builder = builder.b(b);
        }
        if let Some(d) = p.disconnection_distance {
            builder = builder.disconnection_distance(d);
        }
        let progress_tx = tx.clone();
        builder = builder.progress(Box::new(move |fraction: f32, stage: &str| {
            if cancel.load(Ordering::Relaxed) {
                // resume_unwind skips the panic hook: no message is printed.
                panic::resume_unwind(Box::new(Cancelled));
            }
            let _ = progress_tx.send(Msg::Progress(fraction, stage.to_string()));
        }));
        builder.build().map_err(|e| e.to_string())
    })
}

fn panic_message(payload: &(dyn std::any::Any + Send)) -> String {
    if let Some(s) = payload.downcast_ref::<&str>() {
        s.to_string()
    } else if let Some(s) = payload.downcast_ref::<String>() {
        s.clone()
    } else {
        "unknown panic".to_string()
    }
}

/// Row-major `Array2<f32>` from R's column-major double matrix.
fn to_array(x: &RMatrix<f64>, scale: bool) -> Array2<f32> {
    to_f32(x.data(), x.nrows(), x.ncols(), scale)
}

/// Row-major `Array2<f32>` from `n` x `p` column-major doubles. With `scale`,
/// each column is standardised to zero mean and unit variance on the way, in
/// double precision and with the same operations as R's
/// `sweep(sweep(x, 2, centre), 2, sd, "/")`, so that no scaled copy of the
/// data is needed in R. Constant columns become 0.
fn to_f32(values: &[f64], n: usize, p: usize, scale: bool) -> Array2<f32> {
    let mut out = Array2::<f32>::zeros((n, p));
    for j in 0..p {
        let col = &values[j * n..(j + 1) * n];
        let (centre, sd) = if scale {
            column_moments(col)
        } else {
            (0.0, 1.0)
        };
        for (i, &v) in col.iter().enumerate() {
            out[[i, j]] = ((v - centre) / sd) as f32;
        }
    }
    out
}

/// Mean and standard deviation (denominator n - 1) of a column; a standard
/// deviation of 0 is returned as 1, so that constant columns become 0.
fn column_moments(col: &[f64]) -> (f64, f64) {
    let n = col.len().max(1) as f64;
    let mean = col.iter().sum::<f64>() / n;
    let ss: f64 = col.iter().map(|v| (v - mean) * (v - mean)).sum();
    let sd = (ss / (n - 1.0).max(1.0)).sqrt();
    (mean, if sd == 0.0 { 1.0 } else { sd })
}

fn to_real_matrix(a: &Array2<f32>) -> RMatrix<f64> {
    let (n, k) = a.dim();
    RMatrix::new_matrix(n, k, |i, j| a[[i, j]] as f64)
}

fn to_index_matrix(a: &Array2<i32>) -> RMatrix<i32> {
    let (n, k) = a.dim();
    // 1-based for R; upstream marks missing neighbours with -1, which becomes NA.
    RMatrix::new_matrix(n, k, |i, j| {
        if a[[i, j]] < 0 {
            i32::MIN
        } else {
            a[[i, j]] + 1
        }
    })
}

/// Compute a UMAP embedding (internal; use `umap_embed()`).
///
/// @param x Numeric matrix, observations in rows. Must be finite.
/// @param params Named list of parameters (see `umap_params()` in R).
/// @param progress `NULL` or a function `(fraction, stage)` called on the main thread.
/// @param scale Standardise each column (in Rust, without a copy in R)?
/// @return A list with `embedding`, `knn_indices` (1-based) and `knn_distances`;
///   or a string starting with `"interrupt"` / `"error: "`.
/// @noRd
#[extendr]
fn umap_rs(x: RMatrix<f64>, params: List, progress: Robj, scale: bool) -> Result<Robj> {
    let p = parse_params(&params)?;
    let data = to_array(&x, scale);
    let progress_fn = progress.as_function();

    let (tx, rx) = mpsc::channel::<Msg>();
    let cancel = Arc::new(AtomicBool::new(false));
    let worker_cancel = Arc::clone(&cancel);
    let handle = thread::Builder::new()
        .name("ggumap-umap".into())
        .spawn(move || {
            let done_tx = tx.clone();
            let result =
                panic::catch_unwind(AssertUnwindSafe(|| run_umap(data, p, tx, worker_cancel)));
            let result = match result {
                Ok(r) => r,
                Err(payload) if payload.is::<Cancelled>() => Err("interrupt".to_string()),
                Err(payload) => Err(format!("UMAP panicked: {}", panic_message(&*payload))),
            };
            let _ = done_tx.send(Msg::Done(result));
        })
        .map_err(|e| Error::Other(format!("could not start the UMAP thread: {e}")))?;

    let mut interrupted = false;
    let mut callback_error: Option<Error> = None;
    let outcome = loop {
        match rx.recv_timeout(Duration::from_millis(50)) {
            Ok(Msg::Progress(fraction, stage)) => {
                if let (Some(f), false, None) = (&progress_fn, interrupted, &callback_error) {
                    // Never return early: the worker must be stopped and joined first.
                    if let Err(e) = f.call(pairlist!(fraction as f64, stage)) {
                        callback_error = Some(e);
                        cancel.store(true, Ordering::Relaxed);
                    }
                }
            }
            Ok(Msg::Done(result)) => break result,
            Err(mpsc::RecvTimeoutError::Timeout) => {}
            Err(mpsc::RecvTimeoutError::Disconnected) => {
                break Err("the UMAP thread stopped unexpectedly".to_string())
            }
        }
        if !interrupted && user_interrupted() {
            interrupted = true;
            cancel.store(true, Ordering::Relaxed);
        }
    };
    let _ = handle.join();

    if let Some(e) = callback_error {
        return Err(e);
    }
    if interrupted {
        return Ok(Robj::from("interrupt"));
    }
    match outcome {
        Ok(res) => Ok(list!(
            embedding = to_real_matrix(&res.embedding),
            knn_indices = to_index_matrix(&res.knn_indices),
            knn_distances = to_real_matrix(&res.knn_distances)
        )
        .into()),
        Err(e) if e == "interrupt" => Ok(Robj::from("interrupt")),
        Err(e) => Ok(Robj::from(format!("error: {e}"))),
    }
}

/// Version information of the bundled Rust crates (internal).
/// @noRd
#[extendr]
fn umap_rs_info() -> List {
    list!(
        upstream = "apple/embedding-atlas",
        commit = "a0d0f0938db386a86dc855182df3432e1814891d",
        max_threads = thread::available_parallelism()
            .map(|n| n.get() as i32)
            .unwrap_or(1)
    )
}

extendr_module! {
    mod ggumap;
    fn umap_rs;
    fn umap_rs_info;
}

#[cfg(test)]
mod tests {
    use super::*;

    fn params(n_threads: usize) -> Params {
        Params {
            n_components: 2,
            n_neighbors: 10,
            min_dist: 0.1,
            spread: 1.0,
            metric: "euclidean".into(),
            n_epochs: Some(50),
            learning_rate: 1.0,
            negative_sample_rate: 5,
            repulsion_strength: 1.0,
            local_connectivity: 1.0,
            set_op_mix_ratio: 1.0,
            seed: Some(1),
            init: Init::Auto,
            compatibility_layout: true,
            optimizer: None,
            a: None,
            b: None,
            disconnection_distance: None,
            n_threads,
        }
    }

    fn data(n: usize) -> Array2<f32> {
        Array2::from_shape_fn((n, 5), |(i, j)| {
            ((i % 3) * 10 + (i * 7 + j * 13) % 5) as f32
        })
    }

    #[test]
    fn to_f32_converts_column_major_to_row_major() {
        // 2 x 3, column-major: columns (1, 2), (3, 4), (5, 6).
        let a = to_f32(&[1.0, 2.0, 3.0, 4.0, 5.0, 6.0], 2, 3, false);
        assert_eq!(a.dim(), (2, 3));
        assert_eq!(a.row(0).to_vec(), vec![1.0, 3.0, 5.0]);
        assert_eq!(a.row(1).to_vec(), vec![2.0, 4.0, 6.0]);
    }

    #[test]
    fn to_f32_standardises_columns() {
        // Columns (1, 2, 3) and (10, 20, 60).
        let a = to_f32(&[1.0, 2.0, 3.0, 10.0, 20.0, 60.0], 3, 2, true);
        for j in 0..2 {
            let col: Vec<f64> = a.column(j).iter().map(|&v| v as f64).collect();
            let mean = col.iter().sum::<f64>() / 3.0;
            let var = col.iter().map(|v| (v - mean).powi(2)).sum::<f64>() / 2.0;
            assert!(mean.abs() < 1e-6, "column {j} mean {mean}");
            assert!((var - 1.0).abs() < 1e-6, "column {j} variance {var}");
        }
        assert_eq!(a.column(0).to_vec(), vec![-1.0, 0.0, 1.0]);
    }

    #[test]
    fn to_f32_turns_constant_columns_into_zeros() {
        let a = to_f32(&[1.0, 2.0, 3.0, 5.0, 5.0, 5.0], 3, 2, true);
        assert_eq!(a.column(1).to_vec(), vec![0.0, 0.0, 0.0]);
        // A single row: every column is constant.
        let b = to_f32(&[7.0, 8.0], 1, 2, true);
        assert_eq!(b.row(0).to_vec(), vec![0.0, 0.0]);
    }

    #[test]
    fn run_umap_returns_embedding_and_reports_progress() {
        let (tx, rx) = mpsc::channel();
        let cancel = Arc::new(AtomicBool::new(false));
        let res = run_umap(data(90), params(2), tx, cancel).unwrap();
        assert_eq!(res.embedding.dim(), (90, 2));
        assert!(res.embedding.iter().all(|v| v.is_finite()));
        let stages: Vec<String> = rx
            .try_iter()
            .filter_map(|m| match m {
                Msg::Progress(_, s) => Some(s),
                Msg::Done(_) => None,
            })
            .collect();
        assert!(stages.iter().any(|s| s == "Optimizing layout"));
    }

    #[test]
    fn cancellation_unwinds_with_the_cancelled_payload() {
        let (tx, _rx) = mpsc::channel();
        let cancel = Arc::new(AtomicBool::new(true));
        let result = panic::catch_unwind(AssertUnwindSafe(|| {
            run_umap(data(90), params(1), tx, cancel)
        }));
        let payload = result.err().expect("a cancelled run must unwind");
        assert!(payload.is::<Cancelled>());
    }

    #[test]
    fn upstream_errors_become_strings() {
        let (tx, _rx) = mpsc::channel();
        let cancel = Arc::new(AtomicBool::new(false));
        let mut p = params(1);
        p.metric = "nope".into();
        assert!(run_umap(data(30), p, tx, cancel).is_err());
    }

    #[test]
    fn panic_messages_are_extracted() {
        let p: Box<dyn std::any::Any + Send> = Box::new("boom");
        assert_eq!(panic_message(&*p), "boom");
        let p: Box<dyn std::any::Any + Send> = Box::new(String::from("bang"));
        assert_eq!(panic_message(&*p), "bang");
        let p: Box<dyn std::any::Any + Send> = Box::new(42);
        assert_eq!(panic_message(&*p), "unknown panic");
    }
}
