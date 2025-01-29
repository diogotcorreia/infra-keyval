use std::sync::Arc;

use axum::{
    extract::{Path, State},
    http::{header::AUTHORIZATION, HeaderMap, StatusCode},
    routing::{get, post},
    Router,
};
use keyv::{adapter::postgres::PostgresStoreBuilder, Keyv};
use serde_json::Value;

struct AppState {
    keyv: Keyv,
    write_token: String,
}

#[tokio::main]
async fn main() {
    let listen_addr = std::env::var("LISTEN_ADDR").unwrap_or_else(|_| "[::1]:3000".to_owned());
    let db_addr =
        std::env::var("DB_URL").unwrap_or_else(|_| "postgresql://localhost:5432".to_owned());
    let write_token = std::env::var("WRITE_TOKEN").expect("No WRITE_TOKEN provided");

    let store = PostgresStoreBuilder::new()
        .uri(db_addr)
        .table_name("entries")
        .build()
        .await
        .expect("failed to connect to database");

    let keyv = Keyv::try_new(store).await.unwrap();

    let state = Arc::new(AppState { keyv, write_token });

    let app = Router::new()
        .route("/", get(health))
        .route("/{key}", get(get_entry))
        .route("/{key}", post(set_entry))
        .with_state(state);

    let listener = tokio::net::TcpListener::bind(&listen_addr).await.unwrap();
    println!("listening on http://{}", &listen_addr);
    axum::serve(listener, app).await.unwrap();
}

async fn health() -> &'static str {
    "OK"
}

async fn get_entry(
    Path(key): Path<String>,
    State(state): State<Arc<AppState>>,
) -> (StatusCode, String) {
    match state.keyv.get(&key).await {
        Ok(Some(Value::String(value))) => (StatusCode::OK, value),
        Ok(_) => (StatusCode::NOT_FOUND, "entry does not exist".to_owned()),
        Err(_) => (
            StatusCode::INTERNAL_SERVER_ERROR,
            "something went wrong".to_owned(),
        ),
    }
}

async fn set_entry(
    Path(key): Path<String>,
    State(state): State<Arc<AppState>>,
    headers: HeaderMap,
    value: String,
) -> (StatusCode, String) {
    if headers
        .get(AUTHORIZATION)
        .filter(|token| **token == *state.write_token)
        .is_none()
    {
        return (StatusCode::UNAUTHORIZED, "no permission".to_owned());
    }

    match state.keyv.set(&key, value).await {
        Ok(_) => (StatusCode::CREATED, "".to_owned()),
        Err(_) => (
            StatusCode::INTERNAL_SERVER_ERROR,
            "something went wrong".to_owned(),
        ),
    }
}
