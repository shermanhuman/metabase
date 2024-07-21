#!/bin/bash

echo "Current user: $(id)"
echo "Current PATH: $PATH"
echo "Current JAVA_HOME: $JAVA_HOME"
which java
java -version

# Now run the original entrypoint
exec  env PATH=$PATH JAVA_HOME=$JAVA_HOME /app/run_metabase.sh "$@"
