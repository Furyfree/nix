{ ... }:

{
  services.snapper.configs.root = {
    SUBVOLUME = "/";
    FSTYPE = "btrfs";
    SYNC_ACL = false;
    BACKGROUND_COMPARISON = false;
    NUMBER_CLEANUP = true;
    NUMBER_MIN_AGE = 0;
    NUMBER_LIMIT = 6;
    NUMBER_LIMIT_IMPORTANT = 0;
    TIMELINE_CREATE = false;
    TIMELINE_CLEANUP = false;
    EMPTY_PRE_POST_CLEANUP = false;
  };
}
