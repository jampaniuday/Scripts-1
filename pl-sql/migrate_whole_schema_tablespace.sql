
-- big script to migrate all the data from one schema to another tablespace :



prompt
prompt Running MVDS downstream schema tablespace migration
prompt


set serveroutput on


DECLARE
  s_owner VARCHAR2(64) := 'MVDS';
  s_source_tablespace VARCHAR2(64) := 'MERIVAL_MONTHLY_2016Q4';
  s_target_tablespace VARCHAR2(64) := 'MERIVAL_DATA_STATIC';
  i_count INTEGER := 0;

  PROCEDURE run_this(  s_command IN VARCHAR2)
  IS 
  BEGIN
    DBMS_OUTPUT.PUT_LINE( s_command );
    --execute immediate s_command;
  END;

BEGIN
  DBMS_OUTPUT.ENABLE (buffer_size => NULL); 

  --select USER into s_owner from dual;

  DBMS_OUTPUT.PUT_LINE( chr(10) || 'Begininng for account :  ' || s_owner );

  DBMS_OUTPUT.PUT_LINE(chr(10) ||'Moving LOBS : ' );
  DBMS_APPLICATION_INFO.SET_MODULE('Schema migration : ' || s_owner ,'Moving LOBS' );
  FOR c1 IN ( select  table_name, column_name, SEGMENT_NAME,  index_name, tablespace_name from all_lobs DS where tablespace_name = s_source_tablespace and owner = s_owner )
    LOOP
    DBMS_OUTPUT.PUT_LINE('Moving LOB : ' || C1.segment_name || ' / ' || C1.index_name || ' COLUMN : ' || C1.column_name );
    run_this( 'alter table ' || C1.table_name || ' move lob (' || C1.column_name || ') store as (tablespace ' || s_target_tablespace  || ') '    );
    END LOOP;
 
  DBMS_OUTPUT.PUT_LINE(chr(10) ||'Moving tables : ' );
    DBMS_APPLICATION_INFO.SET_MODULE('Schema migration : ' || s_owner ,'Moving tables' );
  for C1 in (
    select  table_name
    from all_tables 
    where partitioned = 'NO' and tablespace_name = s_source_tablespace  and owner = s_owner)
    LOOP
      DBMS_OUTPUT.PUT_LINE('Moving table : ' || c1.table_name);
      run_this( 'alter table  "' || c1.table_name || '" move tablespace ' || s_target_tablespace  )   ;
    END LOOP;

  DBMS_OUTPUT.PUT_LINE(chr(10) || 'Moving indexes : ' );
  DBMS_APPLICATION_INFO.SET_MODULE('Migration :  ' || s_owner ,'Moving indexes' );
  for C1 in (
    select  index_name
    from all_indexes 
    where partitioned = 'NO' and index_type != 'LOB' and tablespace_name = s_source_tablespace  and owner = s_owner)
    LOOP
      DBMS_OUTPUT.PUT_LINE('Moving index : ' || c1.index_name);
      run_this( 'alter index  "' || C1.index_name || '" rebuild tablespace ' || s_target_tablespace   );
    END LOOP;
  ------------------------------------------------------------------------------------------
  -- partition tables
  ------------------------------------------------------------------------------------------
  DBMS_OUTPUT.PUT_LINE(chr(10) || 'Moving partition tables : ' );
  DBMS_APPLICATION_INFO.SET_MODULE('Migration :  ' || s_owner ,'Moving partition tables' );
  for C1 in (
        select table_name
        from all_part_tables DT
        where SUBPARTITIONING_KEY_COUNT = 0 and DEF_TABLESPACE_NAME = s_source_tablespace
           and owner = s_owner
        )
    LOOP
      dbms_output.put_line('Setting default attributes for :  ' || C1.table_name);
      run_this( ' ALTER TABLE ' || C1.table_name || ' MODIFY DEFAULT ATTRIBUTES TABLESPACE ' || s_target_tablespace  ) ;
      DBMS_OUTPUT.PUT_LINE( chr(10) || 'Moving partition table : ' || C1.table_name);
      DBMS_APPLICATION_INFO.SET_MODULE('Migration :  ' || s_owner ,'Moving part tables ' || C1.table_name);
      for partition_list in (select partition_name from all_tab_partitions where  table_name = C1.table_name and tablespace_name = s_source_tablespace  and table_owner = s_owner)
      LOOP
          DBMS_OUTPUT.PUT_LINE('Doing partition ' || partition_list.partition_name );
          --DBMS_APPLICATION_INFO.SET_MODULE('Doing ' || C1.table_name,' partition :  ' || partition_list.partition_name );
          run_this( 'alter table ' || C1.table_name || ' move partition ' || partition_list.partition_name || ' tablespace ' || s_target_tablespace  || ' parallel 16' )  ;
      END LOOP;
    END LOOP;
  ------------------------------------------------------------------------------------------
  -- subpartition tables
  ------------------------------------------------------------------------------------------
  DBMS_OUTPUT.PUT_LINE(chr(10) || 'Moving sub partition tables : ' );
  DBMS_APPLICATION_INFO.SET_MODULE('Migration :  ' || s_owner ,'Moving sub-part tables' );
  for C1 in (
        select table_name
        from all_part_tables DT
        where SUBPARTITIONING_KEY_COUNT != 0 and DEF_TABLESPACE_NAME = s_source_tablespace  and owner = s_owner
        )
    LOOP
      dbms_output.put_line('Setting default attributes for :  ' || C1.table_name);
      run_this( ' ALTER TABLE ' || C1.table_name || ' MODIFY DEFAULT ATTRIBUTES TABLESPACE ' || s_target_tablespace  ) ;
      DBMS_OUTPUT.PUT_LINE( chr(10) || 'Moving sub-partition table : ' || C1.table_name);
      DBMS_APPLICATION_INFO.SET_MODULE('Migration :  ' || s_owner ,'Moving sub-part tables ' || C1.table_name);
      for partition_list in (select subpartition_name from all_tab_subpartitions where  table_name = C1.table_name and tablespace_name = s_source_tablespace  and table_owner = s_owner)
      LOOP
          DBMS_OUTPUT.PUT_LINE('Doing sub partition ' || partition_list.subpartition_name );
          run_this( 'alter table ' || C1.table_name || ' move subpartition ' || partition_list.subpartition_name || ' tablespace ' || s_target_tablespace  || ' parallel 16'  );
      END LOOP;
    END LOOP;

  ------------------------------------------------------------------------------------------
  -- partition indexes
  ------------------------------------------------------------------------------------------
  DBMS_OUTPUT.PUT_LINE(chr(10) || 'Moving partition indexes : ' );
  DBMS_APPLICATION_INFO.SET_MODULE('Migration :  ' || s_owner ,'Moving partition indexes' );
  for C1 in (
            select  index_name, TABLE_NAME
            from all_indexes  UI
            where partitioned = 'YES' and index_type != 'LOB' and tablespace_name = s_source_tablespace  and owner = s_owner
            and not exists ( select 1 from  all_subpart_key_columns P1 where p1.name = UI.table_name )
        )
    LOOP
      run_this('Setting default attributes for :  ' || C1.index_name);
      run_this( ' ALTER INDEX ' || C1.index_name || ' MODIFY DEFAULT ATTRIBUTES TABLESPACE ' || s_target_tablespace  ) ;
      DBMS_OUTPUT.PUT_LINE(chr(10) || 'Moving partition index : ' || C1.index_name);
      DBMS_APPLICATION_INFO.SET_MODULE('Migration :  ' || s_owner ,'Moving part indexes ' || C1.index_name);
      for partition_list in (select partition_name from all_ind_partitions where  index_name = C1.index_name and tablespace_name = s_source_tablespace  and index_owner = s_owner )
      LOOP
          DBMS_OUTPUT.PUT_LINE('Doing partition ' || partition_list.partition_name );
          DBMS_APPLICATION_INFO.SET_MODULE('Migration :  ' || s_owner , 'Moving part : ' || partition_list.partition_name );
          run_this( 'alter index ' || c1.index_name || ' rebuild partition ' || partition_list.partition_name || '  TABLESPACE ' || s_target_tablespace ) ;
      END LOOP;
     
    END LOOP;
 
   ------------------------------------------------------------------------------------------
  -- SUB-partition indexes
  ------------------------------------------------------------------------------------------
  DBMS_OUTPUT.PUT_LINE(chr(10) || 'Moving subpartition indexes : ' );
  DBMS_APPLICATION_INFO.SET_MODULE('Migration :  ' || s_owner ,'Moving subpartition indexes' );
  for C1 in (
            select  index_name, TABLE_NAME
            from all_indexes  UI
            where partitioned = 'YES' and index_type != 'LOB' and tablespace_name = s_source_tablespace  and owner = s_owner
            and exists ( select 1 from  all_subpart_key_columns P1 where p1.name = UI.table_name )
        )
    LOOP
      run_this('Setting default attributes for :  ' || C1.index_name);
      run_this( ' ALTER INDEX ' || C1.index_name || ' MODIFY DEFAULT ATTRIBUTES TABLESPACE ' || s_target_tablespace )  ;
      DBMS_OUTPUT.PUT_LINE(chr(10) || 'Moving sub-partition index : ' || C1.index_name);
      DBMS_APPLICATION_INFO.SET_MODULE('Migration :  ' || s_owner ,'Moving sub-part indexes ' || C1.index_name);
      for partition_list in (select subpartition_name from all_ind_subpartitions where  index_name = C1.index_name and tablespace_name = s_source_tablespace  and index_owner = s_owner)
      LOOP
          DBMS_OUTPUT.PUT_LINE('Doing subpartition ' || partition_list.subpartition_name );
          DBMS_APPLICATION_INFO.SET_MODULE('Migration :  ' || s_owner , 'Moving subpart index : ' || partition_list.subpartition_name );
          run_this( 'alter index ' || c1.index_name || ' rebuild subpartition ' || partition_list.subpartition_name || '  TABLESPACE ' || s_target_tablespace   );
      END LOOP;
     
    END LOOP;


  -- unusable index check :
  select count(*) into i_count from user_indexes where status = 'UNUSABLE' ;
  DBMS_OUTPUT.PUT_LINE( chr(10) ||  'There are ' || i_count || ' unusable indexes' );

  DBMS_APPLICATION_INFO.SET_MODULE(null,null ); 

END;
/

