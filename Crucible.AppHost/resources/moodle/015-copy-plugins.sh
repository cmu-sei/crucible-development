#!/bin/sh

set -e

if [ -z "$PLUGINS" ]; then
  echo "No plugins to install."
  exit 0
fi

# Moodle 5.1+ moved the whole plugin tree under public/; older releases install
# straight into the Moodle root.
WEBROOT="/var/www/html"
if [ -d "$WEBROOT/public" ]; then
  WEBROOT="$WEBROOT/public"
fi
echo "Installing plugins under $WEBROOT"

TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR"

# Cleanup function to ensure we don't leave temporary files
cleanup() {
  echo "Cleaning up temporary files..."
  rm -rf "$TEMP_DIR"
}

# Set trap to ensure cleanup happens even on error
trap cleanup EXIT

# Convert PLUGINS to a list
for entry in $PLUGINS; do
  # Validate format
  if ! echo "$entry" | grep -q "="; then
    echo "Error: Invalid plugin format. Expected 'type_name=url', got '$entry'"
    exit 1
  fi

  plugin_name=$(echo "$entry" | cut -d '=' -f 1)
  plugin_url=$(echo "$entry" | cut -d '=' -f 2)
  plugin_type=$(echo "$plugin_name" | cut -d '_' -f 1)
  plugin_subdir=$(echo "$plugin_name" | cut -d '_' -f 2-)

  echo "Installing plugin $plugin_name from $plugin_url"

  # Download with error handling
  if ! curl -L -s -S -f "$plugin_url" -o "$plugin_name.zip"; then
    echo "Error: Failed to download plugin from $plugin_url"
    exit 1
  fi

  # Unzip with error handling
  if ! unzip -q "$plugin_name.zip"; then
    echo "Error: Failed to unzip $plugin_name.zip"
    exit 1
  fi

  # Move to the corresponding path
  case "$plugin_type" in
     mod) target="$WEBROOT/mod/$plugin_subdir" ;;
    block) target="$WEBROOT/blocks/$plugin_subdir" ;;
    theme) target="$WEBROOT/theme/$plugin_subdir" ;;
    local) target="$WEBROOT/local/$plugin_subdir" ;;
    report) target="$WEBROOT/report/$plugin_subdir" ;;
    auth) target="$WEBROOT/auth/$plugin_subdir" ;;
    filter) target="$WEBROOT/filter/$plugin_subdir" ;;
    gradeexport) target="$WEBROOT/grade/export/$plugin_subdir" ;;
    gradeimport) target="$WEBROOT/grade/import/$plugin_subdir" ;;
    gradereport) target="$WEBROOT/grade/report/$plugin_subdir" ;;
    message) target="$WEBROOT/message/output/$plugin_subdir" ;;
    tool) target="$WEBROOT/admin/tool/$plugin_subdir" ;;
    profilefield) target="$WEBROOT/user/profile/field/$plugin_subdir" ;;
    quiz) target="$WEBROOT/mod/quiz/report/$plugin_subdir" ;;
    plagiarism) target="$WEBROOT/plagiarism/$plugin_subdir" ;;
    portfolio) target="$WEBROOT/portfolio/$plugin_subdir" ;;
    repository) target="$WEBROOT/repository/$plugin_subdir" ;;
    search) target="$WEBROOT/search/$plugin_subdir" ;;
    reportbuilder) target="$WEBROOT/reportbuilder/source/$plugin_subdir" ;;
    payment) target="$WEBROOT/payment/gateway/$plugin_subdir" ;;
    enrol) target="$WEBROOT/enrol/$plugin_subdir" ;;
    assignfeedback) target="$WEBROOT/mod/assign/feedback/$plugin_subdir" ;;
    assignsubmission) target="$WEBROOT/mod/assign/submission/$plugin_subdir" ;;
    quizaccess) target="$WEBROOT/mod/quiz/accessrule/$plugin_subdir" ;;
    workshopallocation) target="$WEBROOT/mod/workshop/allocation/$plugin_subdir" ;;
    workshopassessment) target="$WEBROOT/mod/workshop/assessment/$plugin_subdir" ;;
    workshopform) target="$WEBROOT/mod/workshop/form/$plugin_subdir" ;;
    question) target="$WEBROOT/question/type/$plugin_subdir" ;;
    qbehaviour) target="$WEBROOT/question/behaviour/$plugin_subdir" ;;
    qformat) target="$WEBROOT/question/format/$plugin_subdir" ;;
    editor) target="$WEBROOT/lib/editor/$plugin_subdir" ;;
    tiny) target="$WEBROOT/lib/editor/tiny/plugins/$plugin_subdir" ;;
    atto) target="$WEBROOT/lib/editor/atto/plugins/$plugin_subdir" ;;
    tinymce) target="$WEBROOT/lib/editor/tinymce/plugins/$plugin_subdir" ;;
    availability) target="$WEBROOT/availability/condition/$plugin_subdir" ;;
    datafield) target="$WEBROOT/mod/data/field/$plugin_subdir" ;;
    dataprocessor) target="$WEBROOT/mod/data/preset/$plugin_subdir" ;;
    scormreport) target="$WEBROOT/mod/scorm/report/$plugin_subdir" ;;
    lti) target="$WEBROOT/mod/lti/source/$plugin_subdir" ;;
    contenttype) target="$WEBROOT/contentbank/contenttype/$plugin_subdir" ;;
    courseformat) target="$WEBROOT/course/format/$plugin_subdir" ;;
    customfield) target="$WEBROOT/customfield/field/$plugin_subdir" ;;
    paymentgateway) target="$WEBROOT/payment/gateway/$plugin_subdir" ;;
    analytics) target="$WEBROOT/analytics/indicator/$plugin_subdir" ;;
    aiprovider) target="$WEBROOT/ai/provider/$plugin_subdir" ;;
    aiplacement) target="$WEBROOT/ai/placement/$plugin_subdir" ;;
    cachelock) target="$WEBROOT/cache/lock/$plugin_subdir" ;;
    cachestore) target="$WEBROOT/cache/stores/$plugin_subdir" ;;
    coresearch) target="$WEBROOT/search/engine/$plugin_subdir" ;;
    localcache) target="$WEBROOT/local/cache/$plugin_subdir" ;;
    logstore) target="$WEBROOT/admin/tool/log/store/$plugin_subdir" ;;
    *)
      echo "Warning: Unknown plugin type: $plugin_type"
      echo "Attempting to install in $WEBROOT/$plugin_type/$plugin_subdir"
      target="$WEBROOT/$plugin_type/$plugin_subdir"
      mkdir -p "$(dirname "$target")"
      ;;
  esac

  source_dir="$plugin_subdir"
  if [ ! -d "$source_dir" ]; then
    source_dir_count=$(find . -mindepth 2 -maxdepth 2 -type f -name version.php | wc -l)
    if [ "$source_dir_count" -eq 1 ]; then
      source_dir=$(find . -mindepth 2 -maxdepth 2 -type f -name version.php | sed 's|/version.php$||')
      if ! grep -Fq "$plugin_name" "$source_dir/version.php"; then
        echo "Error: plugin metadata in '$source_dir' does not match '$plugin_name'"
        exit 1
      fi
    fi
  fi

  if [ -d "$source_dir" ]; then
    # Ensure target directory exists
    mkdir -p "$(dirname "$target")"

    # Remove existing plugin if it exists
    if [ -d "$target" ]; then
      echo "Removing existing plugin at $target"
      rm -rf "$target"
    fi

    # Move plugin to target location
    mv "$source_dir" "$target"

    # Set appropriate permissions
    chown -R www-data:www-data "$target" 2>/dev/null || true

    echo "Successfully installed $plugin_name to $target"
  else
    echo "Error: the ZIP does not contain a plugin folder for '$plugin_name'"
    echo "Contents of the ZIP:"
    ls -la
    exit 1
  fi
done

echo "All plugins installed successfully"
