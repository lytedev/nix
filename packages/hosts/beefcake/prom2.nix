{ ... }:
let
  server_name = "prom2";
  dir = "/storage/${server_name}";
  port = 26989;
in
{
  config = {
    systemd.tmpfiles.rules = [
      "d ${dir}/ 0777 1000 1000 -"
      "d ${dir}/data/ 0777 1000 1000 -"
    ];

    virtualisation.oci-containers.containers."minecraft-${server_name}" = {
      autoStart = true;

      # sending commands: https://docker-minecraft-server.readthedocs.io/en/latest/commands/

      image = "docker.io/itzg/minecraft-server";
      extraOptions = [
        "--tty"
        "--interactive"
      ];
      environment = {
        EULA = "true";
        DISABLE_HEALTHCHECK = "true";
        STOP_SERVER_ANNOUNCE_DELAY = "20";
        TZ = "America/Chicago";
        VERSION = "1.20.1";
        MEMORY = "32G";
        MAX_MEMORY = "32G";
        TYPE = "MODRINTH";
        MODRINTH_MODPACK = "prominence-2-fabric";
        MODRINTH_PROJECTS = "simple-voice-chat,distanthorizons:beta";
        MODRINTH_EXCLUDE_FILES = "welcomescreen-fabric-1.0.0-1.20.1.jar";
        ALLOW_FLIGHT = "true";
        ENABLE_QUERY = "true";
        # JVM_OPTS = "--add-modules=jdk.incubator.vector -XX:+UseZGC -XX:-ZProactive -XX:SoftMaxHeapSize=$((Memory - 2048))M -XX:+UnlockExperimentalVMOptions -XX:+UnlockDiagnosticVMOptions -XX:+DisableExplicitGC -XX:+AlwaysPreTouch -XX:+PerfDisableSharedMem -XX:+UseNUMA -XX:-DontCompileHugeMethods -XX:MaxNodeLimit=240000 -XX:NodeLimitFudgeFactor=8000 -XX:ReservedCodeCacheSize=400M -XX:NonNMethodCodeHeapSize=12M -XX:ProfiledCodeHeapSize=194M -XX:NonProfiledCodeHeapSize=194M -XX:NmethodSweepActivity=1 -XX:+UseFastUnorderedTimeStamps -XX:+UseCriticalJavaThreadPriority -XX:AllocatePrefetchStyle=1 -XX:+AlwaysActAsServerClassMachine -XX:+UseTransparentHugePages -XX:LargePageSizeInBytes=2M -XX:+UseLargePages -XX:+EagerJVMCI -XX:+UseStringDeduplication -XX:+UseAES -XX:+UseAESIntrinsics -XX:+UseFMA -XX:+UseLoopPredicate -XX:+RangeCheckElimination -XX:+OptimizeStringConcat -XX:+UseCompressedOops -XX:+UseThreadPriorities -XX:+OmitStackTraceInFastThrow -XX:+RewriteBytecodes -XX:+RewriteFrequentPairs -XX:+UseFPUForSpilling -XX:+UseFastStosb -XX:+UseNewLongLShift -XX:+UseVectorCmov -XX:+UseXMMForArrayCopy -XX:+UseXmmI2D -XX:+UseXmmI2F -XX:+UseXmmLoadAndClearUpper -XX:+UseXmmRegToRegMoveAll -XX:+EliminateLocks -XX:+DoEscapeAnalysis -XX:+AlignVector -XX:+OptimizeFill -XX:+EnableVectorSupport -XX:+UseCharacterCompareIntrinsics -XX:+UseCopySignIntrinsic -XX:+UseVectorStubs -XX:UseAVX=2 -XX:UseSSE=4 -XX:+UseFastJNIAccessors -XX:+UseInlineCaches -XX:+SegmentedCodeCache -Djdk.nio.maxCachedBufferSize=262144 -Djdk.graal.UsePriorityInlining=true -Djdk.graal.Vectorization=true -Djdk.graal.OptDuplication=true -Djdk.graal.DetectInvertedLoopsAsCounted=true -Djdk.graal.LoopInversion=true -Djdk.graal.VectorizeHashes=true -Djdk.graal.EnterprisePartialUnroll=true -Djdk.graal.VectorizeSIMD=true -Djdk.graal.StripMineNonCountedLoops=true -Djdk.graal.SpeculativeGuardMovement=true -Djdk.graal.TuneInlinerExploration=1 -Djdk.graal.LoopRotation=true -Djdk.graal.CompilerConfiguration=enterprise";
        USE_AIKAR_FLAGS = "true";
      };
      environmentFiles = [ ];
      ports = [
        "${toString port}:25565"
        "24454:24454/udp"
      ];
      volumes = [ "${dir}/data:/data" ];
    };
    networking.firewall.allowedTCPPorts = [
      port
      24454 # voice chat mod
    ];
    networking.firewall.allowedUDPPorts = [
      port
      24454 # voice chat mod
    ];

  };
}
