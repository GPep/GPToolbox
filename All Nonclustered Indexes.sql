select t.name as tablename, i.* 
from sys.indexes i, sys.tables t
where i.object_id = t.object_id
  and i.type_desc = 'NONCLUSTERED'