-- This should generally be a low figure
SELECT SUM(pending_disk_io_count) AS [Number of pending I/Os] FROM sys.dm_os_schedulers 


-- This list all pending requests
SELECT *  FROM sys.dm_io_pending_io_requests


-- This show all IO stalls for each database - These will be cumulative since the last SQL restart.
SELECT DB_NAME(database_id) AS [Database],[file_id], io_stall_read_ms,[io_stall_write_ms],[io_stall] FROM sys.dm_io_virtual_file_stats(NULL,NULL) 