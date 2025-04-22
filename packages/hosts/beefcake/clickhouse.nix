{
  lib,
  ...
}:
{
  # clickhouse
  time.timeZone = lib.mkForce "America/Chicago";
  environment.etc = {
    "clickhouse-server/users.d/disable-logging-query.xml" = {
      text = ''
        <clickhouse>
          <profiles>
            <default>
              <log_queries>0</log_queries>
              <log_query_threads>0</log_query_threads>
            </default>
          </profiles>
        </clickhouse>
      '';
    };
    "clickhouse-server/config.d/reduce-logging.xml" = {
      text = ''
        <clickhouse>
          <logger>
            <level>warning</level>
            <console>true</console>
          </logger>
          <query_thread_log remove="remove"/>
          <query_log remove="remove"/>
          <text_log remove="remove"/>
          <trace_log remove="remove"/>
          <metric_log remove="remove"/>
          <asynchronous_metric_log remove="remove"/>
          <session_log remove="remove"/>
          <part_log remove="remove"/>
        </clickhouse>
      '';
    };
  };
  services.restic.commonPaths = [
    # "/var/lib/clickhouse"
  ];
}
