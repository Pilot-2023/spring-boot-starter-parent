#!/bin/bash

set -e # exit when an error occurs

get_maven_property() {
  local property_name="$1"
  local pom_path="${2:-pom.xml}" # Default POM path (can be overridden by second argument)

  # Check if the pom.xml file exists
  if [ ! -f "$pom_path" ]; then
    echo "POM file not found @ $pom_path"
    exit 1
  fi

  # Use Maven Help Plugin to evaluate the property
  value=$(mvn -q -f "$pom_path" help:evaluate -DforceStdout -Dexpression="$property_name" 2>/dev/null)

  # Check for error or empty value
  if [[ $? -ne 0 || -z "$value" ]]; then
    echo "Error retrieving property '$prope rty_name' or property not found."
    exit 1
  fi

  # Return the evaluated property value
  echo "$value"
}

stage() {
  local stage_name="$1"
  echo
  echo
  echo "######################################################"
  echo "#### stage: $stage_name"
  echo "######################################################"
}

stage "Init" #################################################

BRANCH=$CODEBUILD_GIT_BRANCH
SERVICE=$(get_maven_property "project.artifactId") # export is needed to be used in secrets.sh
VERSION=$(get_maven_property "project.version")

echo "GIT BRANCH = $BRANCH"
echo "SERVICE = $SERVICE"
echo "VERSION = $VERSION"

stage "Validate version" #####################################

VERSION_REGEX="[0-9]+\.[0-9]+\.[0-9]+"
SNAPSHOT_REGEX="^$VERSION_REGEX-SNAPSHOT$"
RELEASE_REGEX="^$VERSION_REGEX-RC$"
PRODUCTION_REGEX="^$VERSION_REGEX$"

if [[ "$BRANCH" =~ feature/* ]]; then

  if [[ ! "$VERSION" =~ $SNAPSHOT_REGEX ]]; then
    echo "Invalid SNAPSHOT version"
    exit 1
  fi
  echo "Version $VERSION is a valid SNAPSHOT version"

elif [[ "$BRANCH" == develop ]]; then

  if [[ ! "$VERSION" =~ $SNAPSHOT_REGEX ]]; then
    echo "Invalid SNAPSHOT version"
    exit 1
  fi
  echo "Version $VERSION is a valid SNAPSHOT version"

elif [[ "$BRANCH" =~ release/$VERSION_REGEX ]]; then

  if [[ ! "$VERSION" =~ $RELEASE_REGEX ]]; then
    echo "Invalid RELEASE version"
    exit 1
  fi
  echo "Version $VERSION is a valid RELEASE version"

elif [[ "$BRANCH" =~ main|hotfix/$VERSION_REGEX ]]; then

  if [[ ! "$VERSION" =~ $PRODUCTION_REGEX ]]; then
    echo "Invalid PRODUCTION version"
    exit 1
  fi
  echo "Version $VERSION is a valid PRODUCTION version"

else
  echo "Invalid branch name $BRANCH"
  exit 1
fi

stage "Compile"

mvn clean install
