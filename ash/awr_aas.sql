-- Avg. active sessions = delta database time / delta wall clock elapsed time
--
-- In ASH, we can estimate DB time by counting the number of samples. Basic
-- ASH maths is that COUNT(*) = Time (seconds).
--
-- Therefore, dividing the number of samples by wall clock elapsed time gives
-- us avg. active sessions.
--
-- ASH samples every second e.g. 3600 samples per hour. However, only 1 in 10
-- of these are persisted to the AWR. Therefore, in DBA_HIST_ACTIVE_SESS_HISTORY
-- there are 360 samples per hour.
--
-- This is functionally equivalent to doing a COUNT(10) -  the usual  advice
-- when dealing with DBA_HIST_ACTIVE_SESS_HISTORY
--
-- Note: For CPU, the below query includes both forground and background
-- sessions, whereas for waits it just includes foreground sessions.
--



column inst1_aas format 9,999
column inst2_aas format 9,999
column inst3_aas format 9,999
column inst4_aas format 9,999
column inst5_aas format 9,999
column inst1_cores format 9,999
column inst2_cores format 9,999
column inst3_cores format 9,999
column inst4_cores format 9,999
column inst5_cores format 9,999

colum inst_aas format 9,999
column aas_cpu format 9,999
column aas_io format 9,999
column aas_sysio format 9,999
column aas_concur format 9,999
column aas_admin format 9,999
column aas_commit format 9,999
column aas_app format 9,999
column aas_config format 9,999
column aas_cluster format 9,999
column aas_net format 9,999
column aas_other format 9,999

column sample_min format A21

-- AAS summary at the instance level  :


with 
sub1 as
( select   
    trunc(sample_time,'MI') sample_min,
     CASE  WHEN  session_state in ('WAITING','ON CPU') and instance_number = 1 then 10 else 0 END as inst1,
     CASE  WHEN  session_state in ('WAITING','ON CPU') and instance_number = 2 then 10 else 0 END as inst2,
     CASE  WHEN  session_state in ('WAITING','ON CPU') and instance_number = 3 then 10 else 0 END as inst3,
     CASE  WHEN  session_state in ('WAITING','ON CPU') and instance_number = 4 then 10 else 0 END as inst4,
     CASE  WHEN  session_state in ('WAITING','ON CPU') and instance_number = 5 then 10 else 0 END as inst5
     from
        dba_hist_active_sess_history ash
     where session_type = 'FOREGROUND'
and snap_id  > (select min(snap_id) from dba_hist_snapshot where dbid = (select dbid from v$database) and begin_interval_time  > trunc(sysdate - &DAYS_AGO, 'DD') )
and snap_id  < (select max(snap_id) from dba_hist_snapshot where dbid = (select dbid from v$database) ) 
--    AND sample_time    >= to_timestamp ('WED 08-FEB-2017 16:00')
   )
select sub1.sample_min,
          sum(inst1)/60 inst1_aas,
         ( select value  from   gv$osstat where  stat_name = 'NUM_CPU_CORES' and inst_id = 1 ) inst1_cores,
          sum(inst2)/60 inst2_aas,
        ( select value  from   gv$osstat where  stat_name = 'NUM_CPU_CORES' and inst_id = 2 ) inst2_cores,
          sum(inst3)/60 inst3_aas,
         ( select value  from   gv$osstat where  stat_name = 'NUM_CPU_CORES' and inst_id = 3 ) inst3_cores,
          sum(inst4)/60 inst4_aas,
         ( select value  from   gv$osstat where  stat_name = 'NUM_CPU_CORES' and inst_id = 4 ) inst4_cores,
          sum(inst5)/60 inst5_aas,
       ( select value  from   gv$osstat where  stat_name = 'NUM_CPU_CORES' and inst_id = 5 ) inst5_cores
from sub1
group by sub1.sample_min
order by sub1.sample_min;


-- AAS per minute, per instance, for each wait_class

break on inst_id skip page duplicates


with 
sub1 as
( select   
    trunc(sample_time,'MI') sample_min,
    instance_number as inst_id, 
    ( select value  from   gv$osstat where  stat_name = 'NUM_CPU_CORES' and inst_id = ash.instance_number ) inst_cores,
     CASE  WHEN  session_state = 'WAITING' and wait_class = 'User I/O' then 10 else 0 END as wait_userio,
     CASE  WHEN  session_state = 'WAITING' and wait_class = 'System I/O' then 10 else 0 END as wait_systemio,
     CASE  WHEN session_state = 'WAITING' and wait_class = 'Concurrency' then 10 else 0 END as wait_concurrency,
     CASE  WHEN  session_state = 'WAITING' and wait_class = 'Administrative' then 10 else 0 END as wait_admin,
     CASE  WHEN  session_state = 'WAITING' and wait_class = 'Commit' then 10 else 0 END as wait_commit,
     CASE  WHEN  session_state = 'WAITING' and wait_class = 'Application' then 10 else 0 END as wait_application,
     CASE  WHEN  session_state = 'WAITING' and wait_class = 'Configuration' then 10 else 0 END as wait_config,
     CASE  WHEN  session_state = 'WAITING' and wait_class = 'Cluster' then 10 else 0 END as wait_cluster,
     CASE  WHEN  session_state = 'WAITING' and wait_class = 'Network' then 10 else 0 END as wait_network,
     CASE  WHEN  session_state = 'WAITING' and wait_class = 'Other' then 10 else 0 END as wait_other,     
     CASE  WHEN  session_state = 'WAITING'  then 10 else 0 END as waiting_sess ,
     CASE  WHEN   session_state = 'ON CPU'  then 10 else 0 END as cpu_sess
     from
        dba_hist_active_sess_history ash
     where session_type = 'FOREGROUND'
and snap_id  > (select min(snap_id) from dba_hist_snapshot where dbid = (select dbid from v$database) and begin_interval_time  > trunc(sysdate - &DAYS_AGO, 'DD') )
and snap_id  < (select max(snap_id) from dba_hist_snapshot where dbid = (select dbid from v$database) ) 
 --   AND sample_time    >= to_timestamp ('WED 08-FEB-2017 16:00')
   )
select sub1.sample_min,
          inst_id, 
          sum(sub1.cpu_sess + sub1.waiting_sess)/60 inst_aas,
           sub1.inst_cores, 
           '||',
          sum(sub1.cpu_sess)/60 aas_cpu,
          sum(sub1.wait_userio)/60 aas_io,
          sum(sub1.wait_systemio)/60 aas_sysio,
          sum(sub1.wait_concurrency)/60 aas_concur,
          sum(sub1.wait_admin)/60 aas_admin,
          sum(sub1.wait_commit)/60 aas_commit,
          sum(sub1.wait_application)/60 aas_app,
          sum(sub1.wait_config)/60 aas_config,
          sum(sub1.wait_cluster)/60 aas_cluster,
          sum(sub1.wait_network)/60 aas_net,
          sum(sub1.wait_other)/60 aas_other
from sub1
group by sub1.sample_min, inst_cores, inst_id
order by inst_id, sub1.sample_min;


