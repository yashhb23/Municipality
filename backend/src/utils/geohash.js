'use strict';

const BASE32 = '0123456789bcdefghjkmnpqrstuvwxyz';

/**
 * Encode a latitude/longitude pair into a geohash string.
 *
 * @param {number} lat  Latitude  (-90 to 90).
 * @param {number} lon  Longitude (-180 to 180).
 * @param {number} [precision=7]  Number of characters (7 ≈ ±76 m).
 * @returns {string}
 */
function encode(lat, lon, precision = 7) {
  let latRange = [-90, 90];
  let lonRange = [-180, 180];
  let isLon = true;
  let bit = 0;
  let charIdx = 0;
  let hash = '';

  while (hash.length < precision) {
    const range = isLon ? lonRange : latRange;
    const val = isLon ? lon : lat;
    const mid = (range[0] + range[1]) / 2;

    if (val >= mid) {
      charIdx = (charIdx << 1) | 1;
      range[0] = mid;
    } else {
      charIdx = charIdx << 1;
      range[1] = mid;
    }

    isLon = !isLon;
    bit += 1;

    if (bit === 5) {
      hash += BASE32[charIdx];
      bit = 0;
      charIdx = 0;
    }
  }

  return hash;
}

module.exports = { encode };
