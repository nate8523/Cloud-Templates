# Run Sysprep
Start-Process -filepath 'c:\Windows\system32\sysprep\sysprep.exe' -ErrorAction Stop -ArgumentList '/generalize', '/oobe', '/mode:vm', '/shutdown', '/quiet'