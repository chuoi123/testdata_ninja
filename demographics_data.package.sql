create or replace package demograhics_data

as

  /** Static demograhics data for used for randomizing persons, gender, age etc.
  * @author Morten Egan
  * @version 0.0.1
  * @project RANDOM_NINJA
  */
  npg_version         varchar2(250) := '0.0.1';

  type country_demographics is record (
    p_0_14              number
    , p_15_64           number
    , p_65_             number
    , p_avg_age         number
    , p_avg_age_f       number
    , p_avg_age_m       number
    , p_0_14_mf         number
    , p_15_64_mf        number
    , p_65_mf           number
    , population        number
  );

  type country_demographics_list is table of country_demographics index by varchar2(10);

  c_d_arr       country_demographics_list;

end demograhics_data;
/
