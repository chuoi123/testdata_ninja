create or replace package news_data

as

  /** Constants, Variables and Data for newspaper related generators.
  * @author Morten Egan
  * @version 0.0.1
  * @project TESTDATA_NINJA
  */
  npg_version         varchar2(250) := '0.0.1';

  g_words_per_news_article        number := 1200;

end newspaper_data;
/
