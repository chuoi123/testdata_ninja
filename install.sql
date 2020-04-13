-- Set the correct compilation flags for PLSQL
alter session set plsql_ccflags = 'yl_logger:TRUE';

-- Package Headers
start topological_ninja.package.sql
start testdata_piecebuilder.package.sql
start testdata_data_pattern.package.sql
start testdata_generator_domains.package.sql
start testdata_data_infer.package.sql
start testdata_ninja.package.sql
start testdata_set_generator.package.sql
start demographics_data.package.sql
start testdata_generator.package.sql

-- Package bodies
start "topological_ninja.package body.sql"
start "testdata_piecebuilder.package body.sql"
start "testdata_data_pattern.package body.sql"
start "testdata_generator_domains.package body.sql"
start "testdata_data_infer.package body.sql"
start "testdata_ninja.package body.sql"
start "testdata_set_generator.package body.sql"
start "demographics_data.package body.sql"
start "testdata_generator.package body.sql"