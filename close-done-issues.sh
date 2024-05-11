#! /bin/bash
# Usage: ./close-done-issues.sh \
#  --batch 100
#  --org widal001 
#  --project 3
#  --project-type "user"
#  --status "Done"
#  --dry-run # optionally print items to close before actually closing them
# Closes issues that are in the "Done" column on a project but still open in the repo

# parse command line args with format `--option arg`
# see this stack overflow for more details:
# https://stackoverflow.com/a/14203146/7338319
while [[ $# -gt 0 ]]; do
  case $1 in
    --dry-run)
      echo "Running in dry run mode"
      dry_run=YES
      shift # past argument
      ;;
    --batch)
      batch="$2"
      shift # past argument
      shift # past value
      ;;
    --owner)
      login="$2"
      shift # past argument
      shift # past value
      ;;
    --owner-type)
      owner_type="$2"
      shift # past argument
      shift # past value
      ;;
    --project)
      project="$2"
      shift # past argument
      shift # past value
      ;;
    --status)
      status="$2"
      shift # past argument
      shift # past value
      ;;
    -*|--*)
      echo "Unknown option $1"
      exit 1
      ;;
    *)
      positional_args+=("$1") # save positional arg
      shift # past argument
      ;;
  esac
done

# Create a function to check that required variables are set
check_vars()
{
  # for each variable passed as an argument
  # if a variable is unset, then print it to the console
  var_names=("$@")
  for var_name in "${var_names[@]}"; do
      [ -z "${!var_name}" ] && echo "$var_name is unset." && var_unset=true
  done
  # if at least one variable is unset exit with a non-zero status
  [ -n "$var_unset" ] && exit 1
}

# check that required variables were passed as flags
check_vars batch login project status

# set the login-specific variables
if [[ $owner_type == "organization" ]]; then
  is_org="true"
  owner_prefix="orgs"
elif [[ $owner_type == "user" ]]; then
  is_org="false"
  owner_prefix="users"
else
  echo "--project-type must be one of 'organization' or 'user', not ${owner_type}"
  exit 1
fi

# set script-specific variables
mkdir -p tmp
to_close_file="./tmp/open-issues-that-are-done.txt"
query=$(cat ./get-project-data.graphql)

# print the parsed variables for debugging
echo "Finding open issues in the '${status}' column of GitHub project: ${login}/${project}"

# get all tickets from the project with:
# URL, open/closed state in the repo, and status on the project
gh api graphql \
 --paginate \
 --field login="${login}" \
 --field project="${project}" \
 --field batch="${batch}" \
 --field isOrgProject="${is_org}" \
 -f query="${query}" \
 --jq ".data.${owner_type}.projectV2.items.nodes" |\
 # combine results into a single array
 jq --slurp 'add' |\
 # isolate the URLs of the issues that are marked "Done" in the project
 # but still open in the repo, and use --raw-ouput flag to remove quotes
 jq --raw-output "
 .[]
 | select((.status.name == \"${status}\") and (.issue.state == \"OPEN\"))
 | .issue.url" > $to_close_file  # write output to a file

# iterate through the list of URLs written to the to_close_file
# and close them with a comment indicating the reason for closing
comment="Beep boop: Automatically closing this issue because it was marked as '${status}' "
comment+="in https://github.com/${owner_prefix}/${login}/projects/${project}. "
comment+="This action was performed by a bot."
while read url; do
  if [[ $dry_run == "YES" ]];
  then
    echo "Would close issue with URL: ${url}"
  else
    echo "Closing issue with URL: ${url}"
    gh issue close $url --comment "${comment}"
  fi
done < $to_close_file
