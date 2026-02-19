#!/usr/bin/env node

/**
 * Generate test vectors from the real recharts / recharts-scale implementations.
 *
 * Usage:
 *   node scripts/generate-test-vectors.mjs > scripts/test-vectors.json
 *
 * Prerequisites:
 *   cd _refs/recharts && npm install recharts-scale@0.4.5
 */

import { createRequire } from "node:module";
import { fileURLToPath } from "node:url";
import { dirname, resolve } from "node:path";

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// recharts-scale is installed inside _refs/recharts/node_modules — use CJS require
const require = createRequire(
  resolve(__dirname, "../_refs/recharts/package.json")
);

const { getNiceTickValues, getTickValuesFixedDomain } = require("recharts-scale");

// ---------------------------------------------------------------------------
// Inlined helpers from DataUtils.ts
// ---------------------------------------------------------------------------

function isPercent(value) {
  return typeof value === "string" && value.indexOf("%") === value.length - 1;
}

function isNumber(value) {
  return typeof value === "number" && !Number.isNaN(value);
}

function getPercentValue(percent, totalValue, defaultValue = 0, validate = false) {
  if (!isNumber(percent) && typeof percent !== "string") {
    return defaultValue;
  }

  let value;

  if (isPercent(percent)) {
    const index = percent.indexOf("%");
    value = (totalValue * parseFloat(percent.slice(0, index))) / 100;
  } else {
    value = +percent;
  }

  if (Number.isNaN(value)) {
    value = defaultValue;
  }

  if (validate && value > totalValue) {
    value = totalValue;
  }

  return value;
}

// ---------------------------------------------------------------------------
// Inlined getBarPosition from ChartUtils.ts (simplified — no React elements)
// ---------------------------------------------------------------------------

/**
 * Simplified getBarPosition that mirrors the recharts logic but works without
 * React elements. Each entry in sizeList is { barSize: number | undefined }.
 * Returns an array of { offset, size } (renamed from "width" for clarity).
 */
function getBarPosition({ barGap, barCategoryGap, bandSize, sizeList = [], maxBarSize }) {
  const len = sizeList.length;
  if (len < 1) return null;

  let realBarGap = getPercentValue(barGap, bandSize, 0, true);

  // Check whether barSize was explicitly set (numeric)
  if (sizeList[0].barSize === +sizeList[0].barSize) {
    let useFull = false;
    let fullBarSize = bandSize / len;
    let sum = sizeList.reduce((res, entry) => res + (entry.barSize || 0), 0);
    sum += (len - 1) * realBarGap;

    if (sum >= bandSize) {
      sum -= (len - 1) * realBarGap;
      realBarGap = 0;
    }
    if (sum >= bandSize && fullBarSize > 0) {
      useFull = true;
      fullBarSize *= 0.9;
      sum = len * fullBarSize;
    }

    const offset = ((bandSize - sum) / 2) >> 0;
    let prev = { offset: offset - realBarGap, size: 0 };

    return sizeList.map((entry) => {
      const pos = {
        offset: prev.offset + prev.size + realBarGap,
        size: useFull ? fullBarSize : entry.barSize,
      };
      prev = pos;
      return pos;
    });
  }

  // No explicit barSize — use barCategoryGap to compute
  const catGapOffset = getPercentValue(barCategoryGap, bandSize, 0, true);

  if (bandSize - 2 * catGapOffset - (len - 1) * realBarGap <= 0) {
    realBarGap = 0;
  }

  let originalSize = (bandSize - 2 * catGapOffset - (len - 1) * realBarGap) / len;
  if (originalSize > 1) {
    originalSize = originalSize >> 0; // floor via bitwise shift (matches recharts)
  }
  const size =
    maxBarSize === +maxBarSize ? Math.min(originalSize, maxBarSize) : originalSize;

  return sizeList.map((_entry, i) => ({
    offset: catGapOffset + (originalSize + realBarGap) * i + (originalSize - size) / 2,
    size,
  }));
}

// ---------------------------------------------------------------------------
// Inlined parseSpecifiedDomain from ChartUtils.ts
// ---------------------------------------------------------------------------

const MIN_VALUE_REG = /^dataMin[\s]*-[\s]*([0-9]+([.]{1}[0-9]+){0,1})$/;
const MAX_VALUE_REG = /^dataMax[\s]*\+[\s]*([0-9]+([.]{1}[0-9]+){0,1})$/;

function parseSpecifiedDomain(specifiedDomain, dataDomain, allowDataOverflow = false) {
  if (typeof specifiedDomain === "function") {
    return specifiedDomain(dataDomain, allowDataOverflow);
  }

  if (!Array.isArray(specifiedDomain)) {
    return dataDomain;
  }

  const domain = [];

  // Lower bound
  if (isNumber(specifiedDomain[0])) {
    domain[0] = allowDataOverflow
      ? specifiedDomain[0]
      : Math.min(specifiedDomain[0], dataDomain[0]);
  } else if (MIN_VALUE_REG.test(specifiedDomain[0])) {
    const value = +MIN_VALUE_REG.exec(specifiedDomain[0])[1];
    domain[0] = dataDomain[0] - value;
  } else if (typeof specifiedDomain[0] === "function") {
    domain[0] = specifiedDomain[0](dataDomain[0]);
  } else {
    domain[0] = dataDomain[0];
  }

  // Upper bound
  if (isNumber(specifiedDomain[1])) {
    domain[1] = allowDataOverflow
      ? specifiedDomain[1]
      : Math.max(specifiedDomain[1], dataDomain[1]);
  } else if (MAX_VALUE_REG.test(specifiedDomain[1])) {
    const value = +MAX_VALUE_REG.exec(specifiedDomain[1])[1];
    domain[1] = dataDomain[1] + value;
  } else if (typeof specifiedDomain[1] === "function") {
    domain[1] = specifiedDomain[1](dataDomain[1]);
  } else {
    domain[1] = dataDomain[1];
  }

  return domain;
}

// ===========================================================================
// Test vector generation
// ===========================================================================

// --- Tick generation vectors -----------------------------------------------

const tickCases = [
  { domain: [0, 7], count: 5, allowDecimals: true, label: "basic" },
  { domain: [0, 100], count: 5, allowDecimals: true, label: "round_numbers" },
  { domain: [-10, 10], count: 5, allowDecimals: true, label: "zero_crossing" },
  { domain: [5, 5], count: 5, allowDecimals: true, label: "single_value" },
  { domain: [0, 0.7], count: 5, allowDecimals: true, label: "small_decimals" },
  { domain: [0, 7], count: 5, allowDecimals: false, label: "integer_only" },
  { domain: [100, 10000], count: 5, allowDecimals: true, label: "large_range" },
  { domain: [0, 1], count: 3, allowDecimals: true, label: "few_ticks" },
  { domain: [0, 0], count: 5, allowDecimals: true, label: "zero_domain" },
  { domain: [-100, -10], count: 5, allowDecimals: true, label: "all_negative" },
  { domain: [3, 97], count: 5, allowDecimals: true, label: "non_round" },
];

const tickVectors = tickCases.map(({ domain, count, allowDecimals, label }) => ({
  label,
  input: { domain, count, allowDecimals },
  expected: getNiceTickValues(domain, count, allowDecimals),
}));

// --- Also generate getTickValuesFixedDomain vectors ------------------------

const fixedDomainTickCases = [
  { domain: [0, 100], count: 5, allowDecimals: true, label: "fixed_basic" },
  { domain: [-50, 50], count: 5, allowDecimals: true, label: "fixed_zero_crossing" },
  { domain: [0, 7], count: 5, allowDecimals: false, label: "fixed_integer_only" },
  { domain: [10, 90], count: 5, allowDecimals: true, label: "fixed_mid_range" },
];

const fixedDomainTickVectors = fixedDomainTickCases.map(
  ({ domain, count, allowDecimals, label }) => ({
    label,
    input: { domain, count, allowDecimals },
    expected: getTickValuesFixedDomain(domain, count, allowDecimals),
  })
);

// --- Bar positioning vectors -----------------------------------------------

const barCases = [
  {
    label: "single_bar_defaults",
    input: {
      bandSize: 100,
      barGap: 4,
      barCategoryGap: "10%",
      sizeList: [{ barSize: undefined }],
      maxBarSize: undefined,
    },
  },
  {
    label: "two_bars_defaults",
    input: {
      bandSize: 100,
      barGap: 4,
      barCategoryGap: "10%",
      sizeList: [{ barSize: undefined }, { barSize: undefined }],
      maxBarSize: undefined,
    },
  },
  {
    label: "three_bars_maxBarSize_20",
    input: {
      bandSize: 100,
      barGap: 4,
      barCategoryGap: "10%",
      sizeList: [
        { barSize: undefined },
        { barSize: undefined },
        { barSize: undefined },
      ],
      maxBarSize: 20,
    },
  },
  {
    label: "custom_gaps",
    input: {
      bandSize: 100,
      barGap: "20%",
      barCategoryGap: "15%",
      sizeList: [{ barSize: undefined }, { barSize: undefined }],
      maxBarSize: undefined,
    },
  },
  {
    label: "explicit_barSize_30",
    input: {
      bandSize: 100,
      barGap: 4,
      barCategoryGap: "10%",
      sizeList: [{ barSize: 30 }, { barSize: 30 }],
      maxBarSize: undefined,
    },
  },
];

const barVectors = barCases.map(({ label, input }) => ({
  label,
  input: {
    bandSize: input.bandSize,
    barGap: input.barGap,
    barCategoryGap: input.barCategoryGap,
    sizeList: input.sizeList.map((s) => ({
      barSize: s.barSize === undefined ? null : s.barSize,
    })),
    maxBarSize: input.maxBarSize === undefined ? null : input.maxBarSize,
  },
  expected: getBarPosition(input).map(({ offset, size }) => ({
    offset,
    size,
  })),
}));

// --- Domain parsing vectors ------------------------------------------------

const domainCases = [
  {
    label: "auto_auto",
    specifiedDomain: ["auto", "auto"],
    dataDomain: [20, 100],
    allowDataOverflow: false,
  },
  {
    label: "numeric_fixed",
    specifiedDomain: [-1, 120],
    dataDomain: [20, 100],
    allowDataOverflow: false,
  },
  {
    label: "dataMin_minus_dataMax_plus",
    specifiedDomain: ["dataMin - 10", "dataMax + 10"],
    dataDomain: [20, 100],
    allowDataOverflow: false,
  },
  {
    label: "mixed_zero_dataMax_plus",
    specifiedDomain: [0, "dataMax + 5"],
    dataDomain: [20, 100],
    allowDataOverflow: false,
  },
  {
    label: "allow_data_overflow",
    specifiedDomain: [50, 80],
    dataDomain: [20, 100],
    allowDataOverflow: true,
  },
  {
    label: "numeric_min_clamp",
    specifiedDomain: [30, 120],
    dataDomain: [20, 100],
    allowDataOverflow: false,
  },
  {
    label: "numeric_max_clamp",
    specifiedDomain: [-10, 80],
    dataDomain: [20, 100],
    allowDataOverflow: false,
  },
];

const domainVectors = domainCases.map(
  ({ label, specifiedDomain, dataDomain, allowDataOverflow }) => ({
    label,
    input: {
      specifiedDomain,
      dataDomain,
      allowDataOverflow,
    },
    expected: parseSpecifiedDomain(specifiedDomain, dataDomain, allowDataOverflow),
  })
);

// ===========================================================================
// Output
// ===========================================================================

const output = {
  _meta: {
    generator: "scripts/generate-test-vectors.mjs",
    recharts_scale_version: "0.4.5",
    generated_at: new Date().toISOString(),
  },
  tick_vectors: tickVectors,
  fixed_domain_tick_vectors: fixedDomainTickVectors,
  bar_vectors: barVectors,
  domain_vectors: domainVectors,
};

console.log(JSON.stringify(output, null, 2));
