if object_id(N'usp_calculate_RTO', 'p') is not null
       drop procedure usp_calculate_RTO
   go
   
   raiserror('creating procedure usp_calculate_RTO', 0,1) with nowait
   go
   --
   -- name: proc_calculate_RTO
   --
   -- description: Calculate RTO of a secondary database.
   -- 
   -- parameters:	@secondary_database_name nvarchar(max): name of the secondary database.
   --
   -- security: this is a public interface object.
   --
   create procedure usp_calculate_RTO
   (
   @secondary_database_name nvarchar(max)
   )
   as
   begin
 	  declare @db sysname
 	  declare @is_primary_replica bit 
 	  declare @is_failover_ready bit 
 	  declare @redo_queue_size bigint 
 	  declare @redo_rate bigint
 	  declare @replica_id uniqueidentifier
 	  declare @group_database_id uniqueidentifier
 	  declare @group_id uniqueidentifier
 	  declare @RTO float 

 	  select 
 	  @is_primary_replica = dbr.is_primary_replica, 
 	  @is_failover_ready = dbcs.is_failover_ready, 
 	  @redo_queue_size = dbr.redo_queue_size, 
 	  @redo_rate = dbr.redo_rate, 
 	  @replica_id = dbr.replica_id,
 	  @group_database_id = dbr.group_database_id,
 	  @group_id = dbr.group_id 
 	  from sys.dm_hadr_database_replica_states dbr join sys.dm_hadr_database_replica_cluster_states dbcs 	on dbr.replica_id = dbcs.replica_id and 
 	  dbr.group_database_id = dbcs.group_database_id  where dbcs.database_name = @secondary_database_name

 	  if  @is_primary_replica is null or @is_failover_ready is null or @redo_queue_size is null or @replica_id is null or @group_database_id is null or @group_id is null
 	  begin
 	  	print 'RTO of Database '+ @secondary_database_name +' is not available'
 	  	return
 	  end
 	  else if @is_primary_replica = 1
 	  begin
 	  	print 'You are visiting wrong replica';
 	  	return
 	  end

 	  if @redo_queue_size = 0 
 	  	set @RTO = 0 
 	  else if @redo_rate is null or @redo_rate = 0 
 	  begin
 	  	print 'RTO of Database '+ @secondary_database_name +' is not available'
 	  	return
 	  end
 	  else 
 	  	set @RTO = CAST(@redo_queue_size AS float) / @redo_rate
   
 	  print 'RTO of Database '+ @secondary_database_name +' is ' + convert(varchar, ceiling(@RTO))
 	  print 'group_id of Database '+ @secondary_database_name +' is ' + convert(nvarchar(50), @group_id)
 	  print 'replica_id of Database '+ @secondary_database_name +' is ' + convert(nvarchar(50), @replica_id)
 	  print 'group_database_id of Database '+ @secondary_database_name +' is ' + convert(nvarchar(50), @group_database_id)
   end