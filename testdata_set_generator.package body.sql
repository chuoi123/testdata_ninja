create or replace package body testdata_set_generator

as

  function get_tab_rows (
      table_name_in             in        varchar2
      , owner_in                in        varchar2
  )
  return number

  as

    l_ret_var       number := 1;

  begin

    select num_rows
    into l_ret_var
    from all_tables
    where owner = owner_in
    and table_name = table_name_in;

    return l_ret_var;

  end get_tab_rows;

  procedure generator_set_create (
    set_name                    in        varchar2
    , set_center_table          in        varchar2 default null
    , backward_branching        in        boolean default true
  )

  as

    cursor get_entire_schema is
        with pur as (
            select 
                a.owner
                , a.constraint_name
                , a.constraint_type
                , a.table_name
                , a.r_owner
                , a.r_constraint_name
                , b.column_name local_col
            from 
                all_constraints a, all_cons_columns b
            where 
                a.constraint_type in('P','U','R')
            and 
                a.owner = user
            and
                a.owner = b.owner
            and
                a.constraint_name = b.constraint_name
        )
        , relations as (
            select 
                a.owner
                , a.table_name
                , a.r_owner
                , b.table_name r_table_name
                , b.constraint_type r_constraint_type
                , a.local_col
                , b.local_col remote_col
            from 
                pur a 
            join 
                pur b on (a.r_owner, a.r_constraint_name) = ((b.owner, b.constraint_name))
        )
        , with_parents as (
            select 
                * 
            from 
                relations
            union
            select 
                r_owner
                , r_table_name
                , null
                , null
                , null
                , null
                , null
            from 
                relations 
            where 
                (r_owner, r_table_name) not in (
                    select 
                        owner
                        , table_name
                    from 
                        relations
                    where 
                        (owner, table_name) != ((r_owner, r_table_name))
                )
        )
        select 
            * 
        from (
            select 
                level lvl
                , owner
                , table_name
                , r_owner
                , r_table_name
                , r_constraint_type
                , local_col
                , remote_col
                , connect_by_iscycle is_cycle
            from 
                with_parents
            start with 
                r_owner is null
            connect by 
                nocycle (r_owner, r_table_name) = ((prior owner, prior table_name))
            order siblings by 
                owner, table_name
        );

    cursor get_from_point(start_tab varchar2) is
        with pur as (
            select 
                a.owner
                , a.constraint_name
                , a.constraint_type
                , a.table_name
                , a.r_owner
                , a.r_constraint_name
                , b.column_name local_col
            from 
                all_constraints a, all_cons_columns b
            where 
                a.constraint_type in('P','U','R')
            and 
                a.owner = user
            and
                a.owner = b.owner
            and
                a.constraint_name = b.constraint_name
        )
        , relations as (
            select 
                a.owner
                , a.table_name
                , a.r_owner
                , b.table_name r_table_name
                , b.constraint_type r_constraint_type
                , a.local_col
                , b.local_col remote_col
            from 
                pur a 
            join 
                pur b on (a.r_owner, a.r_constraint_name) = ((b.owner, b.constraint_name))
        )
        , with_parents as (
            select 
                * 
            from 
                relations
            union
            select 
                r_owner
                , r_table_name
                , null
                , null
                , null
                , null
                , null
            from 
                relations 
            where 
                (r_owner, r_table_name) not in (
                    select 
                        owner
                        , table_name
                    from 
                        relations
                    where 
                        (owner, table_name) != ((r_owner, r_table_name))
                )
        )
        select 
            * 
        from (
            select 
                level lvl
                , owner
                , table_name
                , r_owner
                , r_table_name
                , r_constraint_type
                , local_col
                , remote_col
                , connect_by_iscycle is_cycle
            from 
                with_parents
            start with 
                table_name = upper(start_tab)
            connect by 
                nocycle (r_owner, r_table_name) = ((prior owner, prior table_name))
            order siblings by 
                owner, table_name
        );

    type ref_rec is record (
        lvl                 number
        , owner             varchar2(128)
        , table_name        varchar2(128)
        , r_owner           varchar2(128)
        , r_table_name      varchar2(128)
        , r_constraint_type varchar2(128)
        , local_col         varchar2(128)
        , remote_col        varchar2(128)
        , is_cycle          number
    );
    type ref_tab is table of ref_rec;
    l_tables_to_generators  ref_tab := ref_tab();

    type circular_ref_rec is record (
        local_column        varchar2(128)
        , remote_table      varchar2(128)
        , remote_column     varchar2(128)
    );
    type circular_ref_tab is table of circular_ref_rec index by varchar2(128);
    l_circular_refs         circular_ref_tab;
    l_first_root            boolean := true;
    type table_list_data_rec is record (
        table_lvl       number
        , table_name    varchar2(128)
    );
    type tables_list_tab is table of table_list_data_rec;
    type tables_merged_tab is table of number index by varchar2(128);
    l_tables_list_order     tables_list_tab := tables_list_tab();
    l_merged_table_list     tables_merged_tab;
    type constraints_list_tab is table of varchar2(4000) index by varchar2(512);
    l_primary_keys          constraints_list_tab;
    l_foreign_keys          constraints_list_tab;
    l_table_primary_col     constraints_list_tab;
    l_constraint_stmt       varchar2(4000);
    l_constraint_hash       varchar2(512);
    l_tmp_index             varchar2(128);
    type priority_list_tab is table of varchar2(128);
    type ordered_list_tab is table of priority_list_tab;
    l_final_order           ordered_list_tab;
    l_highest_order         number := 0;
    l_constraint_iter       number := 1;

    l_main_pkg_header       varchar2(32000);
    l_main_pkg_body         varchar2(32000);
    l_e_set_name_to_long    exception;
    pragma                  exception_init(l_e_set_name_to_long, -25042);
    type tab_to_rows_tab is table of number index by varchar2(128);
    l_tables_to_rows        tab_to_rows_tab;
    l_first_tab_count       number;
    l_first_setsize         boolean := false;

  begin

    if length(set_name) > 8 then
        raise_application_error(-25000, 'Set name is to long. Must be between 1 and 8 characters');
    end if;

    if set_center_table is null then
        -- Fetch all tables from top level
        open get_entire_schema;
        fetch get_entire_schema bulk collect into l_tables_to_generators;
        close get_entire_schema;
    else
        -- Fetch from starting point
        open get_from_point(set_center_table);
        fetch get_from_point bulk collect into l_tables_to_generators;
        close get_from_point;
    end if;

    -- Now we have all the tables needed for this and a bit more.
    -- We filter the list and make sure we only have unique names
    -- and in the right order.
    for i in 1..l_tables_to_generators.count loop
        -- Set the highest order
        if l_tables_to_generators(i).lvl > l_highest_order then
            l_highest_order := l_tables_to_generators(i).lvl;
        end if;

        -- If we have the first table set the first tab count.
        if i = 1 then
            l_first_tab_count := get_tab_rows(l_tables_to_generators(i).table_name, l_tables_to_generators(i).owner);
            l_tables_to_rows(l_tables_to_generators(i).table_name) := l_first_tab_count;
        else
            l_tables_to_rows(l_tables_to_generators(i).table_name) := round(get_tab_rows(l_tables_to_generators(i).table_name, l_tables_to_generators(i).owner)/(l_first_tab_count/100),2);
        end if;

        if l_tables_to_generators(i).is_cycle = 1 then
            -- Register circular refs.
            l_circular_refs(l_tables_to_generators(i).table_name).local_column := l_tables_to_generators(i).local_col;
            l_circular_refs(l_tables_to_generators(i).table_name).remote_table := l_tables_to_generators(i).r_table_name;
            l_circular_refs(l_tables_to_generators(i).table_name).remote_column := l_tables_to_generators(i).remote_col;
        end if;

        if l_tables_to_generators(i).lvl = 1 then
            -- First level. Check if we are beginning wit a new root table.
            if l_first_root then
                -- First root table met. Maybe do something special here. 
                l_first_root := false;
            else
                -- n root table met. We need to sort and merge the result of l_tables_list_order
                -- and then reset for new circle of references.
                for y in 1..l_tables_list_order.count loop
                  if l_merged_table_list.exists(l_tables_list_order(y).table_name) then
                    -- already exist so only check if we need lower build priority
                    if l_tables_list_order(y).table_lvl > l_merged_table_list(l_tables_list_order(y).table_name) then
                        l_merged_table_list(l_tables_list_order(y).table_name) := l_tables_list_order(y).table_lvl;
                    end if;
                  else
                    l_merged_table_list(l_tables_list_order(y).table_name) := l_tables_list_order(y).table_lvl;
                  end if;
                end loop;
                l_tables_list_order := tables_list_tab();
            end if;
            -- This is first level table. Only add table.
            l_tables_list_order.extend(1);
            l_tables_list_order(l_tables_list_order.count).table_lvl := l_tables_to_generators(i).lvl;
            l_tables_list_order(l_tables_list_order.count).table_name := l_tables_to_generators(i).table_name;
        else
            -- Higher level table met. Add table, primary key of r_ table and foreign key 
            l_tables_list_order.extend(1);
            l_tables_list_order(l_tables_list_order.count).table_lvl := l_tables_to_generators(i).lvl;
            l_tables_list_order(l_tables_list_order.count).table_name := l_tables_to_generators(i).table_name;
            -- Add the primary key unless it already exists.
            l_constraint_stmt := 'alter table '|| l_tables_to_generators(i).r_table_name ||' add constraint pk_'|| l_tables_to_generators(i).r_table_name || '_##ITER##' || ' primary key(' || l_tables_to_generators(i).remote_col ||')';
            select ora_hash(l_constraint_stmt)
            into l_constraint_hash
            from dual;
            if not l_primary_keys.exists(l_constraint_hash) then
                l_primary_keys(l_constraint_hash) := replace(l_constraint_stmt, '##ITER##', l_constraint_iter);
                l_table_primary_col(l_tables_to_generators(i).r_table_name) := l_tables_to_generators(i).remote_col;
                l_constraint_iter := l_constraint_iter + 1;
            end if;
            -- Add the foreign key unless it already exists.
            -- The add statement differs if table is in the circular reference table already.
            -- If that is the case we need to make the constraint deferred because of circular updates.
            l_constraint_stmt := 'alter table '|| l_tables_to_generators(i).table_name ||' add constraint fk_'|| l_tables_to_generators(i).r_table_name || '_##ITER##' || ' foreign key('|| l_tables_to_generators(i).local_col ||') references '|| l_tables_to_generators(i).r_table_name || '(' || l_tables_to_generators(i).remote_col ||')';
            select ora_hash(l_constraint_stmt)
            into l_constraint_hash
            from dual;
            if not l_foreign_keys.exists(l_constraint_hash) then
                l_foreign_keys(l_constraint_hash) := replace(l_constraint_stmt, '##ITER##', l_constraint_iter);
                l_constraint_iter := l_constraint_iter + 1;
            end if;
        end if;
    end loop;

    -- Final merge
    for y in 1..l_tables_list_order.count loop
      if l_merged_table_list.exists(l_tables_list_order(y).table_name) then
        -- already exist so only check if we need lower build priority
        if l_tables_list_order(y).table_lvl > l_merged_table_list(l_tables_list_order(y).table_name) then
            l_merged_table_list(l_tables_list_order(y).table_name) := l_tables_list_order(y).table_lvl;
        end if;
      else
        l_merged_table_list(l_tables_list_order(y).table_name) := l_tables_list_order(y).table_lvl;
      end if;
    end loop;

    -- First initialize final order collections.
    l_final_order := ordered_list_tab();
    for i in 1..l_highest_order loop
      l_final_order.extend(1);
      l_final_order(i) := priority_list_tab();
    end loop;
    -- Then we go through l_merged_table_list to do correct order.
    l_tmp_index := l_merged_table_list.first;
    while l_tmp_index is not null loop
        l_final_order(l_merged_table_list(l_tmp_index)).extend(1);
        l_final_order(l_merged_table_list(l_tmp_index))(l_final_order(l_merged_table_list(l_tmp_index)).count) := l_tmp_index;
        l_tmp_index := l_merged_table_list.next(l_tmp_index);
    end loop;

    -- Now we can build the actual generators.
    for i in 1..l_final_order.count loop
        for y in 1..l_final_order(i).count loop
            testdata_ninja.generator_create(
                generator_name          =>      set_name || '_' || l_final_order(i)(y)
                , generator_table       =>      l_final_order(i)(y)
            );
        end loop;
    end loop;

    -- Dynamically creating the main package that can build the dataset remotely.
    l_main_pkg_header := 'create or replace package tdg_main_' || set_name || '
        authid current_user
        as
            
            g_default_set_size          number := 100;
            
            procedure build_set (
                set_size                number default g_default_set_size
                , predictable_key       varchar2 default to_char(systimestamp,''FFSSMIHH24DDMMYYYY'') || sys_context(''USERENV'', ''SESSIONID'')
                , overwrite             boolean default false
            );
            
        end tdg_main_' || set_name || ';';

    execute immediate l_main_pkg_header;

    l_main_pkg_body := 'create or replace package body tdg_main_' || set_name || '
        as
        
            procedure build_set (
                set_size                number default g_default_set_size
                , predictable_key       varchar2 default to_char(systimestamp,''FFSSMIHH24DDMMYYYY'') || sys_context(''USERENV'', ''SESSIONID'')
                , overwrite             boolean default false
            )
            
            as

                l_setsize_baseline              number := '|| l_first_tab_count ||';
                l_generator_rowcount            number;';

    l_tmp_index := l_circular_refs.first;
    while l_tmp_index is not null loop
        l_main_pkg_body := l_main_pkg_body || '
                l_pred_k_' || l_tmp_index || '      varchar2(4000) := build_set.predictable_key;';
        l_tmp_index := l_circular_refs.next(l_tmp_index);
    end loop;
    
    l_main_pkg_body := l_main_pkg_body || '            
            begin

                if set_size < 100 then
                    l_setsize_baseline := round(l_setsize_baseline*(set_size/100));
                end if;
            
                ';
    for i in 1..l_final_order.count loop
        for y in 1..l_final_order(i).count loop
            if not l_first_setsize then
                l_main_pkg_body := l_main_pkg_body || '
                        tdg_' || set_name || '_' || l_final_order(i)(y) || '.to_table(
                            table_name          =>      '''|| l_final_order(i)(y) ||'''
                            , generator_count   =>      l_setsize_baseline
                            , predictable_key   =>      build_set.predictable_key
                            , overwrite         =>      build_set.overwrite
                        );';
                l_first_setsize := true;
            else
                l_main_pkg_body := l_main_pkg_body || '
                        tdg_' || set_name || '_' || l_final_order(i)(y) || '.to_table(
                            table_name          =>      '''|| l_final_order(i)(y) ||'''
                            , generator_count   =>      round((l_setsize_baseline/100)*'|| l_tables_to_rows(l_final_order(i)(y)) ||')
                            , predictable_key   =>      build_set.predictable_key
                            , overwrite         =>      build_set.overwrite
                        );';
            end if;
        end loop;
    end loop;
    l_tmp_index := l_primary_keys.first;
    while l_tmp_index is not null loop
        l_main_pkg_body := l_main_pkg_body || '
                        execute immediate '''|| l_primary_keys(l_tmp_index) ||''';';
        l_tmp_index := l_primary_keys.next(l_tmp_index);
    end loop;

    -- TODO: This is where we should resolve data in circular tables before adding foreign keys.
    l_tmp_index := l_circular_refs.first;
    while l_tmp_index is not null loop
        l_main_pkg_body := l_main_pkg_body || '
                        -- Resolve circular reference for ' || l_tmp_index || '('|| l_circular_refs(l_tmp_index).local_column ||') against ' || l_circular_refs(l_tmp_index).remote_table || '(' || l_circular_refs(l_tmp_index).remote_column || ')';
        l_main_pkg_body := l_main_pkg_body || '
                        execute immediate ''update ' || l_tmp_index || ' cf
                        set cf.' || l_circular_refs(l_tmp_index).local_column || ' = (select cd.' || l_circular_refs(l_tmp_index).local_column || ' from table(tdg_' || set_name || '_' || l_tmp_index || '.' || set_name || '_' || l_tmp_index || '(round(('' || l_setsize_baseline || ''/100)*'|| l_tables_to_rows(l_tmp_index) ||'), ''''''|| l_pred_k_' || l_tmp_index || ' ||'''''')) cd where cd.' || l_table_primary_col(l_tmp_index) || ' = cf.' || l_table_primary_col(l_tmp_index) || ')'';';
        l_tmp_index := l_circular_refs.next(l_tmp_index);
    end loop;

    l_tmp_index := l_foreign_keys.first;
    while l_tmp_index is not null loop
        l_main_pkg_body := l_main_pkg_body || '
                        execute immediate '''|| l_foreign_keys(l_tmp_index) ||''';';
        l_tmp_index := l_foreign_keys.next(l_tmp_index);
    end loop;
    l_main_pkg_body := l_main_pkg_body || '
            
            end build_set;

        end tdg_main_' || set_name || ';';

    execute immediate l_main_pkg_body;

  end generator_set_create;

end testdata_set_generator;
/