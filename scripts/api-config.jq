# AppHost JSON permits comments and trailing commas. Match complete strings first
# so URL slashes, escaped quotes, and comment-like password text remain literal.
def jsonc:
  sub("^\uFEFF"; "")
  | [scan("\"(?:[^\"\\\\]|\\\\.)*\"|//[^\\r\\n]*|/\\*(?:[^*]|\\*(?!/))*\\*/|[^\"/]+|/")
     | if startswith("//") then "\n" elif startswith("/*") then " " else . end]
  | join("")
  | gsub("(?<string>\"(?:[^\"\\\\]|\\\\.)*\")|,(?<closing>\\s*[}\\]])";
      if .string != null then .string else .closing end)
  | fromjson
  | if type == "object" then . else error("Expected a settings object") end;

# Match .NET's case-insensitive configuration keys, without changing their casing.
def key_ci($key):
  [keys_unsorted[] | select(ascii_downcase == ($key | ascii_downcase))][0] // $key;
def get_ci($key):
  if type == "object" then .[key_ci($key)] else null end;
def set_ci($key; $value): .[key_ci($key)] = $value;
def merge_ci($base; $overlay):
  reduce ($overlay | to_entries[]) as $entry ($base;
    (get_ci($entry.key)) as $old
    | set_ci($entry.key;
        if ($old | type) == "object" and ($entry.value | type) == "object"
        then merge_ci($old; $entry.value) else $entry.value end));

# Add another wired API's resource/launch names here to validate it on selection.
def apps:
  [
    {app: "topomojo", launch: ["TopoMojo", "TopoMojoLaunchpoint"]},
    {app: "player-vm-api", launch: ["Player"]},
    {app: "caster-api", launch: ["Caster"]}
  ];
def launched($launch; $env; $names):
  any($names[];
    . as $name
    | ($env | get_ci("Launch__" + $name)) as $flag
    | (if $flag == null then ($launch | get_ci($name)) == true
       else ($flag | ascii_downcase) == "true" end)
      or any(["Dev", "Prod"][];
        . as $group | any(($launch | get_ci($group))[]?;
          ascii_downcase == ($name | ascii_downcase)))
      or any($env | to_entries[];
        (.key | test("^Launch__(Dev|Prod)__[0-9]+$"; "i"))
        and (.value | ascii_downcase) == ($name | ascii_downcase)));

(if $local_file == "/dev/null" then {} else ($local_text | jsonc) end) as $settings
| ($settings | get_ci("Launch") // {}) as $local_launch
| ($local_launch | get_ci("ApiConfig") // {}) as $api
| if $mode == "status" then
    if ($api | get_ci("Enabled")) == true then ($api | get_ci("Profile"))
    else "disabled in local settings" end
  elif $profile == "remove" then
    {required: [], settings:
      ($settings | set_ci("Launch";
        $local_launch | set_ci("ApiConfig"; $api | set_ci("Enabled"; false))))}
  else
    ($base_text | jsonc) as $base
    | (merge_ci($base; $settings) | get_ci("Launch") // {}) as $launch
    | ($launch | get_ci("ApiConfig") | get_ci("Apps") // {}) as $overrides
    | env as $env
    | [apps[] | . as $app
        | ($env | get_ci("Launch__ApiConfig__Apps__" + $app.app + "__Enabled")) as $enabled
        | select(launched($launch; $env; $app.launch))
        | select(if $enabled == null
            then ($overrides | get_ci($app.app) | get_ci("Enabled")) != false
            else ($enabled | ascii_downcase) != "false" end)
        | $app.app] as $required
    | ($overrides | with_entries(
        .key as $app
        | .value |= with_entries(select((.key | ascii_downcase) != "profile"))
        # Clearing a local override must not reveal an override from base settings.
        | if ($base | get_ci("Launch") | get_ci("ApiConfig") | get_ci("Apps")
              | get_ci($app) | get_ci("Profile")) != null
          then .value |= set_ci("Profile"; $profile) else . end)) as $updated
    | {required: $required, settings:
        ($settings | set_ci("Launch"; $local_launch | set_ci("ApiConfig";
          $api | set_ci("Apps"; $updated) | set_ci("Enabled"; true) | set_ci("Profile"; $profile))))}
  end
