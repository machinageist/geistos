use serde_json::{json, Value};
use std::{fs, process::Command};

// All filesystem artifacts are confined to the explicitly supplied scratch root.
fn fixture() -> Value {
    let evidence = json!([{"id":"e", "producer":"synthetic-test", "source_record":"fixture", "revision":"1", "digest":"synthetic-digest"}]);
    let criteria: Vec<_> = ["missing", "failing", "stale", "evidence-free", "passing"].iter().map(|id| {
        let verifications = if *id == "missing" { json!([]) } else { json!([{
            "id":format!("v-{id}"), "criterion_id":id, "subject_revision": if *id == "stale" {1} else {2},
            "evidence":if *id == "evidence-free" {json!([])} else {evidence.clone()},
            "result":if *id == "failing" {"Fail"} else {"Pass"}, "verifier":"synthetic", "attempt":1
        }]) };
        json!({"id":id,"statement":"synthetic criterion","verifications":verifications})
    }).collect();
    json!({"interop_schema":"mg.plan/1","kind":"plan","producer":{"app":"mg-plan","app_version":"synthetic"},
        "plan_revision":7,"plan":{"id":"synthetic-plan","title":"Synthetic", "dependencies":[],
        "work_items":{"work":{"id":"work","title":"Synthetic work","status":"InProgress","revision":2,"criteria":criteria}}}})
}

#[test]
fn offline_gap_checklist_cli_is_advisory_read_only_and_reference_bound() {
    let root = std::env::var("TMPDIR").expect("set TMPDIR to approved scratch");
    assert!(root.starts_with("/home/mgeist/.hermes/cache/scratch/"));
    let dir = tempfile::tempdir_in(root).unwrap();
    let file = dir.path().join("synthetic.json");
    let original = serde_json::to_vec(&fixture()).unwrap();
    fs::write(&file, &original).unwrap();
    let invoke = |id: &str, revision: &str| {
        Command::new(env!("CARGO_BIN_EXE_mg-plan"))
            .arg("gap-checklist")
            .arg(&file)
            .args([id, revision])
            .output()
            .unwrap()
    };
    let output = invoke("synthetic-plan", "7");
    assert!(
        output.status.success(),
        "{}",
        String::from_utf8_lossy(&output.stderr)
    );
    let report: Value = serde_json::from_slice(&output.stdout).unwrap();
    assert_eq!(report["advisory"], true);
    assert_eq!(report["schema"], "mg.plan.gap-checklist/1");
    assert_eq!(report["plan_id"], "synthetic-plan");
    assert_eq!(report["plan_revision"], 7);
    let entries = report["entries"].as_array().unwrap();
    assert_eq!(entries.len(), 4);
    for reason in [
        "MissingVerification",
        "NonPassingVerification",
        "StaleVerification",
        "MissingEvidence",
    ] {
        let entry = entries.iter().find(|e| e["reason"] == reason).unwrap();
        assert!(!entry["explanation"].as_str().unwrap().is_empty());
        assert!(!entry["suggested_source"].as_str().unwrap().is_empty());
        assert!(entry.get("passed").is_none());
    }
    assert!(report["notice"].as_str().unwrap().contains("Only mg-plan"));
    for (id, revision) in [
        ("other", "7"),
        ("", "7"),
        ("synthetic-plan", "6"),
        ("synthetic-plan", "0"),
        ("synthetic-plan", "NaN"),
    ] {
        let result = invoke(id, revision);
        assert!(!result.status.success());
        assert!(result.stdout.is_empty());
    }
    assert_eq!(fs::read(&file).unwrap(), original);
    for field in ["interop_schema", "kind"] {
        let mut invalid = fixture();
        invalid[field] = json!("invalid");
        fs::write(&file, serde_json::to_vec(&invalid).unwrap()).unwrap();
        assert!(!invoke("synthetic-plan", "7").status.success());
    }
    for result in ["Inconclusive", "Waived"] {
        let mut snapshot = fixture();
        snapshot["plan"]["work_items"]["work"]["criteria"][1]["verifications"][0]["result"] =
            json!(result);
        fs::write(&file, serde_json::to_vec(&snapshot).unwrap()).unwrap();
        let output = invoke("synthetic-plan", "7");
        assert!(output.status.success());
        let report: Value = serde_json::from_slice(&output.stdout).unwrap();
        assert!(report["entries"]
            .as_array()
            .unwrap()
            .iter()
            .any(|entry| entry["criterion_id"] == "failing"
                && entry["reason"] == "NonPassingVerification"));
    }
    let mut invalid = fixture();
    invalid["producer"]["app"] = json!("AI");
    fs::write(&file, serde_json::to_vec(&invalid).unwrap()).unwrap();
    assert!(!invoke("synthetic-plan", "7").status.success());
    fs::write(&file, b"{}").unwrap();
    assert!(!invoke("synthetic-plan", "7").status.success());
    assert_eq!(fs::read_dir(dir.path()).unwrap().count(), 1);
}
