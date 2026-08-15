mod actions;
mod fzf;
mod params;
mod render;

fn main() {
    let args: Vec<String> = std::env::args().skip(1).collect();
    match run(&args) {
        Ok(Some(output)) => {
            println!("{output}");
        }
        Ok(None) => {}
        Err(message) => {
            eprintln!("{message}");
            std::process::exit(2);
        }
    }
}

fn run(args: &[String]) -> Result<Option<String>, String> {
    match args.first().map(String::as_str) {
        Some("--list") => Ok(Some(
            actions::actions()
                .iter()
                .map(|action| action.candidate_row())
                .collect::<Vec<_>>()
                .join("\n"),
        )),
        Some("--preview") => {
            let id = args
                .get(1)
                .ok_or_else(|| "usage: jjp-bin --preview <action-id>".to_string())?;
            let action = actions::find_action(id).ok_or_else(|| format!("unknown action: {id}"))?;
            Ok(Some(action.preview()))
        }
        Some("--print") => {
            let id = args
                .get(1)
                .ok_or_else(|| "usage: jjp-bin --print <action-id> [name=value ...]".to_string())?;
            let action = actions::find_action(id).ok_or_else(|| format!("unknown action: {id}"))?;
            if args.len() == 2 {
                return Ok(Some(render::render_action_with_defaults(action)));
            }
            let mut values = render::default_values(action);
            for arg in args.iter().skip(2) {
                let (name, value) = arg
                    .split_once('=')
                    .ok_or_else(|| format!("expected name=value override, got: {arg}"))?;
                values.insert(name.to_string(), value.to_string());
            }
            Ok(Some(render::render_action(action, &values)))
        }
        Some(flag) if flag.starts_with('-') => Err(format!("unknown flag: {flag}")),
        Some(_) | None => {
            let query = if args.is_empty() {
                None
            } else {
                Some(args.join(" "))
            };
            let Some(id) = fzf::select_action(query.as_deref())? else {
                return Ok(None);
            };
            let action =
                actions::find_action(&id).ok_or_else(|| format!("unknown action: {id}"))?;
            let Some(values) = params::resolve_params(action)? else {
                return Ok(None);
            };
            Ok(Some(render::render_action(action, &values)))
        }
    }
}

#[cfg(test)]
mod tests {
    use crate::actions::find_action;
    use crate::render::render_action_with_defaults;

    #[test]
    fn render_land_main_with_defaults() {
        let action = find_action("land-main").expect("land-main");
        assert_eq!(
            render_action_with_defaults(action),
            "jj sync && jj evolve && jj tug main && jjgp --bookmark main"
        );
    }
}
