use crate::actions::{Action, ParamSpec};
use crate::fzf;
use crate::render;
use std::collections::HashMap;
use std::io::{self, IsTerminal, Write};
use std::process::Command;

pub fn resolve_params(action: &Action) -> Result<Option<HashMap<String, String>>, String> {
    let mut values = render::default_values(action);

    for param in action.params {
        match param {
            ParamSpec::Bookmark {
                name,
                default,
                prompt,
            } => {
                if !prompt {
                    continue;
                }
                let Some(value) = select_bookmark(default)? else {
                    return Ok(None);
                };
                values.insert((*name).to_string(), value);
            }
            ParamSpec::Revision {
                name,
                default,
                prompt,
            } => {
                if !prompt {
                    continue;
                }
                let Some(value) = select_revision(default)? else {
                    return Ok(None);
                };
                values.insert((*name).to_string(), value);
            }
            ParamSpec::File { name } => {
                let Some(value) = select_file()? else {
                    return Ok(None);
                };
                values.insert((*name).to_string(), value);
            }
            ParamSpec::Remote { name } => {
                let Some(value) = select_remote()? else {
                    return Ok(None);
                };
                values.insert((*name).to_string(), value);
            }
            ParamSpec::Text { name, prompt } => {
                let value = prompt_text(prompt)?;
                values.insert((*name).to_string(), value);
            }
        }
    }

    Ok(Some(values))
}

fn select_bookmark(default: &Option<&'static str>) -> Result<Option<String>, String> {
    let mut rows = command_lines("jj", &["bookmark", "list"])?;
    if rows.is_empty() {
        if let Some(default) = default {
            rows.push((*default).to_string());
        }
    }
    let rows = rows
        .into_iter()
        .map(|line| {
            line.split(':')
                .next()
                .unwrap_or(line.as_str())
                .trim()
                .to_string()
        })
        .filter(|line| !line.is_empty())
        .collect::<Vec<_>>();
    fzf::select_value("bookmark>", &rows)
}

fn select_revision(default: &Option<&'static str>) -> Result<Option<String>, String> {
    let rows = command_lines(
        "jj",
        &["log", "-r", "trunk() | @ | ancestors(@, 20)", "--no-graph"],
    )?;
    if rows.is_empty() {
        return Ok(default.map(|value| value.to_string()));
    }
    fzf::select_value("revision>", &rows)
}

fn select_file() -> Result<Option<String>, String> {
    let mut rows = command_lines("jj", &["diff", "--name-only"])?;
    if rows.is_empty() {
        rows = command_lines("jj", &["file", "list"])?;
    }
    fzf::select_value("file>", &rows)
}

fn select_remote() -> Result<Option<String>, String> {
    let rows = command_lines("jj", &["git", "remote", "list"])?
        .into_iter()
        .map(|line| line.split_whitespace().next().unwrap_or("").to_string())
        .filter(|line| !line.is_empty())
        .collect::<Vec<_>>();
    fzf::select_value("remote>", &rows)
}

fn prompt_text(prompt: &str) -> Result<String, String> {
    if !io::stdin().is_terminal() {
        return Err(format!("{prompt} requires an interactive terminal"));
    }
    eprint!("{prompt} ");
    io::stderr()
        .flush()
        .map_err(|err| format!("failed to flush prompt: {err}"))?;
    let mut value = String::new();
    io::stdin()
        .read_line(&mut value)
        .map_err(|err| format!("failed to read input: {err}"))?;
    Ok(value.trim_end().to_string())
}

fn command_lines(program: &str, args: &[&str]) -> Result<Vec<String>, String> {
    let output = Command::new(program)
        .args(args)
        .output()
        .map_err(|err| format!("failed to run {program} {}: {err}", args.join(" ")))?;
    if !output.status.success() {
        return Ok(Vec::new());
    }
    Ok(String::from_utf8_lossy(&output.stdout)
        .lines()
        .map(str::to_string)
        .collect())
}
