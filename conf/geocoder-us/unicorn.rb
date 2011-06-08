worker_processes 4
user "www-data", "www-data"
listen "/var/run/geocoder-us/unicorn.sock", :backlog => 64
pid "/var/run/geocoder-us/unicorn.pid"
stderr_path "/var/log/geocoder-us/geocoder-err.log"
stdout_path "/var/log/geocoder-us/geocoder-out.log"

# Have each process listen on a local port for debugging purposes.
after_fork do |server, worker|
    addr = "127.0.0.1:#{40000 + worker.nr}"
    server.listen(addr, :tries => 1, :delay => 5, :tcp_nopush => true)
end
