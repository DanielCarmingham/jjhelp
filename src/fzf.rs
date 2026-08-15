use crate::actions;
use std::io::Write;
use std::process::{Command, Stdio};

pub fn select_action(query: Option<&str>) -> Result<Option<String>, String> {
    let rows = actions::actions()
        .iter()
        .map(|action| action.candidate_row())
        .collect::<Vec<_>>();
    select_rows("action>", &rows, query, Some("jjp-bin --preview {1}"))
}

pub fn select_value(prompt: &str, rows: &[String]) -> Result<Option<String>, String> {
    select_rows(prompt, rows, None, None)
}

fn select_rows(
    prompt: &str,
    rows: &[String],
    query: Option<&str>,
    preview: Option<&str>,
) -> Result<Option<String>, String> {
    let mut command = Command::new("fzf");
    command
        .arg("--delimiter")
        .arg("\t")
        .arg("--with-nth")
        .arg("2..")
        .arg("--prompt")
        .arg(prompt)
        .stdin(Stdio::piped())
        .stdout(Stdio::piped());

    if let Some(preview) = preview {
        command.arg("--preview").arg(preview);
    }

    if let Some(query) = query {
        command.arg("--query").arg(query);
    }

    let mut child = command
        .spawn()
        .map_err(|err| format!("failed to run fzf: {err}"))?;

    {
        let stdin = child
            .stdin
            .as_mut()
            .ok_or_else(|| "failed to open fzf stdin".to_string())?;
        for row in rows {
            writeln!(stdin, "{row}").map_err(|err| format!("failed to write fzf input: {err}"))?;
        }
    }

    let output = child
        .wait_with_output()
        .map_err(|err| format!("failed to wait for fzf: {err}"))?;

    if !output.status.success() {
        return Ok(None);
    }

    let selected = String::from_utf8_lossy(&output.stdout);
    let selected = selected.trim();
    if selected.is_empty() {
        return Ok(None);
    }

    Ok(selected.split('\t').next().map(str::to_string))
}
