if object_id(N'usp_calculate_RPO', 'p') is not null
   				drop procedure usp_calculate_RPO
   go
   
   raiserror('creating procedure usp_calculate_RPO', 0,1) with nowait
   go
   --
   -- name: proc_calculate_RPO
   --
   -- description: Calculate RPO of a secondary database.
   -- 
   -- parameters:	@group_id uniqueidentifier: group_id of the secondary database.
   --				@replica_id uniqueidentifier: replica_id of the secondary database.
   --				@group_database_id uniqueidentifier: group_database_id of the secondary database.
   --
   -- security: this is a public interface object.
   --
   create procedure usp_calculate_RPO
   (
    @group_id uniqueidentifier,
    @replica_id uniqueidentifier,
    @group_database_id uniqueidentifier
   )
   as
   begin
   	  declare @db_name sysname
   	  declare @is_primary_replica bit
   	  declare @is_failover_ready bit
   	  declare @is_local bit
   	  declare @last_commit_time_sec datetime 
   	  declare @last_commit_time_pri datetime      
   	  declare @RPO nvarchar(max) 

   	  -- secondary database's last_commit_time 
   	  select 
   	  @db_name = dbcs.database_name,
   	  @is_failover_ready = dbcs.is_failover_ready, 
   	  @last_commit_time_sec = dbr.last_commit_time 
   	  from sys.dm_hadr_database_replica_states dbr join sys.dm_hadr_database_replica_cluster_states dbcs on dbr.replica_id = dbcs.replica_id and 
   	  dbr.group_database_id = dbcs.group_database_id  where dbr.group_id = @group_id and dbr.replica_id = @replica_id and dbr.group_database_id = @group_database_id

   	  -- correlated primary database's last_commit_time 
   	  select
   	  @last_commit_time_pri = dbr.last_commit_time,
   	  @is_local = dbr.is_local
   	  from sys.dm_hadr_database_replica_states dbr join sys.dm_hadr_database_replica_cluster_states dbcs on dbr.replica_id = dbcs.replica_id and 
   	  dbr.group_database_id = dbcs.group_database_id  where dbr.group_id = @group_id and dbr.is_primary_replica = 1 and dbr.group_database_id = @group_database_id

   	  if @is_local is null or @is_failover_ready is null
   	  begin
   	  	print 'RPO of database '+ @db_name +' is not available'
   	  	return
   	  end

   	  if @is_local = 0
   	  begin
   	  	print 'You are visiting wrong replica'
   	  	return
   	  end  

   	  if @is_failover_ready = 1
   	  	set @RPO = '00:00:00'
   	  else if @last_commit_time_sec is null or  @last_commit_time_pri is null 
   	  begin
   	  	print 'RPO of database '+ @db_name +' is not available'
   	  	return
   	  end
   	  else
   	  begin
   	  	if DATEDIFF(ss, @last_commit_time_sec, @last_commit_time_pri) < 0
   	  	begin
   	  		print 'RPO of database '+ @db_name +' is not available'
   	  		return
   	  	end
   	  	else
   	  		set @RPO =  CONVERT(varchar, DATEADD(ms, datediff(ss ,@last_commit_time_sec, @last_commit_time_pri) * 1000, 0), 114)
   	  end
   	  print 'RPO of database '+ @db_name +' is ' + @RPO
     end