# Docker Registry V2 Cleanup
Bash script to cleanup a private docker registry V2

Make the file executeable
```
chmod +x ./cleaner.sh
```

Change the variables to fit your needs
```
UREGI="your.registry.com:5000"              # Registry URL
PROTOCOL="https://"                         # Http or Https
REGCONT="my_registry_1"                     # Name of the registry container
REGCONF="/etc/docker/registry/config.yml"   # Config file of the registry
REMOVE_LATEST="false"                       # Remove latest tags
REMOVE_VERSION="false"                      # Remove version tags
DRY_RUN="true"                              # Enable fake run
```

Run the script (dry run first is recommended)
```
./cleaner.sh
```


# Hi Contributors
Feel free to make PR's to make this script even better.

