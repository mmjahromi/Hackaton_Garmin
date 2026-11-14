import Toybox.Lang;
module Config {
    function defaults() {
        return {:schemaVersion=>1, :goalSec=>1200, :hrLowBpm=>120, :hrHighBpm=>140,
            :recoverBpm=>135, :easeAfterSec=>15, :walkAfterSec=>60, :recoverHoldSec=>30,
            :minWalkSec=>60, :clearEaseSec=>15, :hrReacquireSec=>10};
    }
    function valid(c) {
        if (!(c instanceof Dictionary)) { return false; }
        var d = defaults();
        var keys = d.keys();
        for (var i = 0; i < keys.size(); i++) {
            if (!c.hasKey(keys[i]) || !Contracts.numberIn(c[keys[i]], 0, 3600)) { return false; }
        }
        return c[:schemaVersion] == 1 && c[:hrLowBpm] >= 40 &&
            c[:hrLowBpm] < c[:recoverBpm] && c[:recoverBpm] < c[:hrHighBpm] &&
            c[:hrHighBpm] <= 220 && c[:goalSec] >= 60 && c[:goalSec] <= 3600 &&
            c[:easeAfterSec] == 15 && c[:walkAfterSec] == 60 &&
            c[:recoverHoldSec] == 30 && c[:minWalkSec] == 60 &&
            c[:clearEaseSec] == 15 && c[:hrReacquireSec] == 10;
    }
}
