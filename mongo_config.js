db.createUser( { 
    user: username,
    pwd: password,
    roles: [
        { role: "readWriteAnyDatabase", db: "admin" },
        { role: "backup", db: "admin" },
        { role: "restore", db: "admin" }
    ] } )
