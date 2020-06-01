use std::collections::HashSet;
use std::env;
use std::error::Error;
use std::sync::{Arc, Mutex};

use async_std::task;
use lazy_static::lazy_static;
use prometheus::{register_gauge_vec, Encoder, GaugeVec, TextEncoder};
use serde_derive::{Deserialize, Serialize};
use tide::http::StatusCode;
use tide::{Body, Response};

#[derive(Debug, Serialize, Deserialize)]
struct StatusPage {
    status: Status,
}

#[derive(Debug, Serialize, Deserialize)]
struct Status {
    indicator: String,
    description: String,
}

static STATUS_URL: &'static str = "https://status.packet.com/api/v2/status.json";

lazy_static! {
    static ref PACKET_STATUS: GaugeVec = register_gauge_vec!(
        "packet_status_page_indicator",
        "The current indicator of the packet status page.",
        &["indicator"]
    )
    .unwrap();
}

async fn metrics(labels: Arc<Mutex<HashSet<String>>>) -> Result<Response, tide::Error> {
    let page: StatusPage = surf::get(STATUS_URL).recv_json().await?;
    println!(
        "Packet status {}, {}",
        page.status.indicator, page.status.description
    );

    let mut labels = labels.lock().unwrap();

    for indicator in labels.iter() {
        PACKET_STATUS.with_label_values(&[indicator]).set(0 as f64);
    }

    PACKET_STATUS
        .with_label_values(&[&page.status.indicator])
        .set(1 as f64);

    labels.insert(page.status.indicator);

    let encoder = TextEncoder::new();
    let metric_families = prometheus::gather();
    let mut buffer = vec![];
    encoder.encode(&metric_families, &mut buffer)?;

    let resp = Response::new(StatusCode::Ok).body(Body::from(buffer));
    Ok(resp)
}

fn main() -> Result<(), Box<dyn Error>> {
    let labels = Arc::new(Mutex::new(
        vec!["none", "maintenance", "minor", "critical"]
            .into_iter()
            .map(String::from)
            .collect(),
    ));

    let mut server = tide::new();
    server.at("/metrics").get(move |_| metrics(labels.clone()));

    let port = env::var("PORT").unwrap_or(String::from("9122"));
    println!("Listening on http://127.0.0.1:{}", port);
    task::block_on(server.listen(format!("0.0.0.0:{}", port)))?;
    Ok(())
}
