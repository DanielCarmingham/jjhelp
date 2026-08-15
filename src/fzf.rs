use crate::actions;
use std::io::Write;
use std::process::{Command, Stdio};

pub fn select_action(query: Option<&str>) -> Result<Option<String>, String> {
    let rows = actions::actions()
        .iter()
        .map(|action| action.candidate_row())
        .collect::<Vec<_>>();
    select_rows(
        action_palette_args(Some("jjp-bin --preview {1}"), query),
        &rows,
    )
}

pub fn select_value(prompt: &str, rows: &[String]) -> Result<Option<String>, String> {
    select_rows(value_palette_args(prompt), rows)
}

fn select_rows(args: Vec<String>, rows: &[String]) -> Result<Option<String>, String> {
    let mut command = Command::new("fzf");
    command
        .args(args)
        .stdin(Stdio::piped())
        .stdout(Stdio::piped());

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

fn action_palette_args(preview: Option<&str>, query: Option<&str>) -> Vec<String> {
    action_palette_args_with_popup(preview, query, supports_popup())
}

fn action_palette_args_with_popup(
    preview: Option<&str>,
    query: Option<&str>,
    use_popup: bool,
) -> Vec<String> {
    let mut args = base_palette_args("jj › ", use_popup);
    args.extend([
        "--with-nth".to_string(),
        "2".to_string(),
        "--nth".to_string(),
        "2..".to_string(),
    ]);

    if let Some(preview) = preview {
        args.extend(["--preview".to_string(), preview.to_string()]);
    }

    if let Some(query) = query {
        args.extend(["--query".to_string(), query.to_string()]);
    }

    args
}

fn value_palette_args(prompt: &str) -> Vec<String> {
    let mut args = base_palette_args(prompt, supports_popup());
    args.extend(["--with-nth".to_string(), "1..".to_string()]);
    args
}

fn base_palette_args(prompt: &str, use_popup: bool) -> Vec<String> {
    let mut args = vec![
        "--delimiter".to_string(),
        "\t".to_string(),
        "--ansi".to_string(),
        "--prompt".to_string(),
        prompt.to_string(),
        "--layout=reverse".to_string(),
        "--border=double".to_string(),
        "--border-label= jj palette ".to_string(),
        "--border-label-pos=2".to_string(),
        "--margin=1,2".to_string(),
        "--padding=1,2".to_string(),
        "--info=inline-right".to_string(),
        "--highlight-line".to_string(),
        "--gap".to_string(),
        "--pointer=›".to_string(),
        "--marker=+".to_string(),
        "--preview-label= command ".to_string(),
        "--preview-label-pos=2".to_string(),
        "--preview-window".to_string(),
        "right:55%,border-double,wrap".to_string(),
        "--color=prompt:6,pointer:6,marker:2,hl:4,hl+:4,border:4,preview-border:4,label:6,preview-label:6"
            .to_string(),
    ];

    if use_popup {
        args.push("--popup=center,90%,75%,border-native".to_string());
    } else {
        args.push("--height=70%".to_string());
    }

    args
}

fn supports_popup() -> bool {
    std::env::var_os("TMUX").is_some() || std::env::var_os("ZELLIJ").is_some()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn action_palette_uses_clean_prompt_and_searches_hidden_metadata() {
        let args =
            action_palette_args_with_popup(Some("jjp-bin --preview {1}"), Some("land"), false);

        assert!(args.contains(&"--prompt".to_string()));
        assert!(args.contains(&"--ansi".to_string()));
        assert!(args.contains(&"jj › ".to_string()));
        assert!(!args.contains(&"action>".to_string()));
        assert!(args.windows(2).any(|pair| pair == ["--with-nth", "2"]));
        assert!(args.windows(2).any(|pair| pair == ["--nth", "2.."]));
        assert!(args.contains(&"--border=double".to_string()));
        assert!(args.contains(&"--layout=reverse".to_string()));
        assert!(args.contains(&"--height=70%".to_string()));
        assert!(args.contains(&"--pointer=›".to_string()));
    }

    #[test]
    fn palette_uses_labeled_padded_retro_window_chrome() {
        let args = action_palette_args_with_popup(Some("jjp-bin --preview {1}"), None, false);

        assert!(args.contains(&"--border=double".to_string()));
        assert!(args.contains(&"--border-label= jj palette ".to_string()));
        assert!(args.contains(&"--padding=1,2".to_string()));
        assert!(args.contains(&"--margin=1,2".to_string()));
        assert!(args.contains(&"--highlight-line".to_string()));
        assert!(args.contains(&"--gap".to_string()));
        assert!(args.contains(&"--preview-label= command ".to_string()));
        assert!(args
            .windows(2)
            .any(|pair| pair == ["--preview-window", "right:55%,border-double,wrap"]));
    }

    #[test]
    fn palette_can_use_host_popup_for_true_floating_window() {
        let args = base_palette_args("jj › ", true);

        assert!(args.contains(&"--popup=center,90%,75%,border-native".to_string()));
        assert!(!args.contains(&"--height=70%".to_string()));
    }
}
