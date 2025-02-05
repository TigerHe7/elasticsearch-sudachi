#!/usr/bin/env bash

set -euxo pipefail
DEFAULT_ES_VERSION=8.2.3
ES_VERSION=${ES_VERSION:-$DEFAULT_ES_VERSION}
SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]:-$0}"; )" &> /dev/null && pwd 2> /dev/null; )";
WORK_DIR="${WORK_DIR:-$(readlink -f "$SCRIPT_DIR/../build/integration")}"
ES_DIR="$WORK_DIR/$ES_KIND-${ES_VERSION}"
ES_KIND=${ES_KIND:-$ES_KIND}
DIC_VERSION=${DIC_VERSION:-latest}
DIC_KIND=${DIC_KIND:-small}
unset JAVA_HOME

if [[ "$ES_KIND" == "elasticsearch" ]]; then
  ES_URL="https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-${ES_VERSION}-linux-x86_64.tar.gz"
  ES_BIN=elasticsearch
  ES_PLUGIN_BIN=elasticsearch-plugin
  ES_FILE="$WORK_DIR/$ES_KIND-${ES_VERSION}-linux-x86_64.tar.gz"

  IFS='.' read -ra VERS <<< "$ES_VERSION"
  if [[ ("${VERS[0]}" -eq 7 && "${VERS[1]}" -lt 14) || ("${VERS[0]}" -eq 8 && "${VERS[1]}" -lt 5) ]]; then
    SHOULD_RUN_TEST01="false"
  else
    SHOULD_RUN_TEST01="true"
  fi
elif [[ "$ES_KIND" == "opensearch" ]]; then
  ES_URL="https://artifacts.opensearch.org/releases/bundle/opensearch/${ES_VERSION}/opensearch-${ES_VERSION}-linux-x64.tar.gz"
  ES_BIN=opensearch
  ES_PLUGIN_BIN=opensearch-plugin
  ES_FILE="$WORK_DIR/$ES_KIND-${ES_VERSION}-linux-x64.tar.gz"
  SHOULD_RUN_TEST01="true"
else
  echo "Error: script supports only Elasticsearch or OpenSearch, was '$ES_KIND'"
  exit 1
fi


PLUGIN_PATH="$SCRIPT_DIR/../build/distributions/$ES_KIND-$ES_VERSION-analysis-sudachi-$PLUGIN_VERSION.zip"
TEST_PLUGIN_PATH="$SCRIPT_DIR/../integration/build/distributions/$ES_KIND-$ES_VERSION-integration-$PLUGIN_VERSION.zip"

if [[ ! -f "$PLUGIN_PATH" ]]; then
  echo "Plugin is not built, run ./gradlew build"
  exit 1
fi

if [[ "$SHOULD_RUN_TEST01" == "true" && ! -f "$TEST_PLUGIN_PATH" ]]; then
  echo "Test plugin is not built, run ./gradlew build"
  exit 1
fi

mkdir -p "$WORK_DIR"
pushd "$PWD"

cd "$WORK_DIR"

if [[ ! -f $ES_FILE ]]; then
  wget --progress=dot:giga "$ES_URL"
fi

if [[ ! -d "$ES_DIR" ]]; then
  tar xf "$ES_FILE"
fi


PLUGIN_PATH="$(readlink -f "$PLUGIN_PATH")"
PLUGIN="file://$PLUGIN_PATH"

if [[ -d "$ES_DIR/plugins/analysis-sudachi" ]]; then
  "$ES_DIR/bin/$ES_PLUGIN_BIN" remove analysis-sudachi
fi

"$ES_DIR/bin/$ES_PLUGIN_BIN" install "$PLUGIN"

if [[ "$SHOULD_RUN_TEST01" == "true" ]]; then
  TEST_PLUGIN_PATH="$(readlink -f "$TEST_PLUGIN_PATH")"
  TEST_PLUGIN="file://$TEST_PLUGIN_PATH"

  if [[ -d "$ES_DIR/plugins/analysis-icu" ]]; then
    "$ES_DIR/bin/$ES_PLUGIN_BIN" remove analysis-icu
  fi
  if [[ -d "$ES_DIR/plugins/analysis-sudachi-childtest" ]]; then
    "$ES_DIR/bin/$ES_PLUGIN_BIN" remove analysis-sudachi-childtest
  fi

  "$ES_DIR/bin/$ES_PLUGIN_BIN" install "analysis-icu"
  "$ES_DIR/bin/$ES_PLUGIN_BIN" install "$TEST_PLUGIN"
fi


if [[ "$ES_KIND" == "elasticsearch" ]]; then
  cp "$SCRIPT_DIR/elasticsearch.yml" "$ES_DIR/config/elasticsearch.yml"
else
  cp "$SCRIPT_DIR/opensearch.yml" "$ES_DIR/config/opensearch.yml"
fi


DIC_ZIP_PATH="$WORK_DIR/sudachi-dictionary-$DIC_VERSION-$DIC_KIND.zip"

if [[ ! -f "$DIC_ZIP_PATH" ]]; then
  wget --progress=dot:giga "http://sudachi.s3-website-ap-northeast-1.amazonaws.com/sudachidict/sudachi-dictionary-$DIC_VERSION-$DIC_KIND.zip"
fi

if [[ "$ES_DIR/config/sudachi/system_core.dic" -ot "$DIC_ZIP_PATH" ]]; then
  mkdir -p "$ES_DIR/config/sudachi"
  unzip -p "$DIC_ZIP_PATH" "*/system_$DIC_KIND.dic" > "$ES_DIR/config/sudachi/system_core.dic"
fi

if [[ "$SHOULD_RUN_TEST01" == "true" ]]; then
  TEST_DIC_PATH="$SCRIPT_DIR/../integration/build/generated/dict/system.dict"
  TEST_DIC_PATH="$(readlink -f "$TEST_DIC_PATH")"

  if [[ "$ES_DIR/config/sudachi/system_test.dic" -ot "$TEST_DIC_PATH" ]]; then
    cp "$TEST_DIC_PATH" "$ES_DIR/config/sudachi/system_test.dic"
  fi
fi


# log sudachi plugin messages with debug level
if ! grep -qF "com.worskap.nlp" "$ES_DIR/config/log4j2.properties"; then
cat >> "$ES_DIR/config/log4j2.properties" <<'EOF'
# sudachi debugging
logger.sudachi.name = com.worksap.nlp
logger.sudachi.level = debug
EOF
fi

if [[ -n "$RUN_ES_DAEMON" ]]; then
  "$ES_DIR/bin/$ES_BIN" -d
fi

date --iso-8601=seconds
popd