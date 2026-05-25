#!/usr/bin/env python3
"""Generates Hyperfocus.xcodeproj/project.pbxproj from scratch."""

# All UUIDs are 24 uppercase hex characters.
# Pattern: category prefix (2 chars) + sequential (22 chars).

# ─── Object IDs ────────────────────────────────────────────────────────────────
P  = "AA000000000000000000000A"  # PBXProject
MG = "AA000000000000000000000B"  # Main group
PG = "AA000000000000000000000C"  # Products group
AT = "AA000000000000000000000D"  # Hyperfocus app target
TT = "AA000000000000000000000E"  # HyperfocusTests target
AP = "AA000000000000000000000F"  # Hyperfocus.app (product ref)
TP = "AA0000000000000000000010"  # HyperfocusTests.xctest (product ref)

# Config lists
CL_PROJ     = "AA0000000000000000000020"
CL_APP      = "AA0000000000000000000021"
CL_TEST     = "AA0000000000000000000022"
# Build configurations
CFG_PROJ_D  = "AA0000000000000000000030"
CFG_PROJ_R  = "AA0000000000000000000031"
CFG_APP_D   = "AA0000000000000000000032"
CFG_APP_R   = "AA0000000000000000000033"
CFG_TEST_D  = "AA0000000000000000000034"
CFG_TEST_R  = "AA0000000000000000000035"

# Build phases
APP_SOURCES = "AA0000000000000000000040"
APP_RES     = "AA0000000000000000000041"
APP_FW      = "AA0000000000000000000042"
TEST_SOURCES= "AA0000000000000000000043"
TEST_FW     = "AA0000000000000000000044"
TEST_RES    = "AA0000000000000000000045"

# Groups
GRP_WORKHOUR= "AA000000000000000000G000"  # Hyperfocus/ source folder
GRP_MODELS  = "AA000000000000000000G001"
GRP_STORES  = "AA000000000000000000G002"
GRP_SERVICES= "AA000000000000000000G003"
GRP_VIEWS   = "AA000000000000000000G004"
GRP_TIMER   = "AA000000000000000000G005"
GRP_STATS   = "AA000000000000000000G006"
GRP_UTIL    = "AA000000000000000000G007"
GRP_TESTS   = "AA000000000000000000G008"

# ─── Source files: (uid, build_uid, path, group, is_resource) ──────────────────
APP_FILES = [
    # (ref_id, build_id, filename, parent_group)
    # All paths are relative to their parent group (which resolves under Hyperfocus/)
    ("AA0000000000000000000100", "AA0000000000000000000200", "HyperfocusApp.swift",                GRP_WORKHOUR),
    ("AA0000000000000000000101", "AA0000000000000000000201", "Session.swift",                    GRP_MODELS),
    ("AA0000000000000000000102", "AA0000000000000000000202", "Cycle.swift",                      GRP_MODELS),
    ("AA0000000000000000000103", "AA0000000000000000000203", "PersistedState.swift",              GRP_MODELS),
    ("AA0000000000000000000104", "AA0000000000000000000204", "Clock.swift",                       GRP_SERVICES),
    ("AA0000000000000000000105", "AA0000000000000000000205", "Persistence.swift",                 GRP_SERVICES),
    ("AA0000000000000000000106", "AA0000000000000000000206", "SleepObserver.swift",               GRP_SERVICES),
    ("AA0000000000000000000107", "AA0000000000000000000207", "TimerStore.swift",                  GRP_STORES),
    ("AA0000000000000000000108", "AA0000000000000000000208", "StatisticsStore.swift",             GRP_STORES),
    ("AA0000000000000000000109", "AA0000000000000000000209", "TimeFormatting.swift",              GRP_UTIL),
    ("AA000000000000000000010A", "AA000000000000000000020A", "SessionAggregation.swift",          GRP_UTIL),
    ("AA000000000000000000010B", "AA000000000000000000020B", "MenuBarLabel.swift",                GRP_VIEWS),
    ("AA000000000000000000010C", "AA000000000000000000020C", "PopoverRoot.swift",                 GRP_VIEWS),
    ("AA000000000000000000010D", "AA000000000000000000020D", "TimeDisplayView.swift",             GRP_TIMER),
    ("AA000000000000000000010E", "AA000000000000000000020E", "SessionNameField.swift",            GRP_TIMER),
    ("AA000000000000000000010F", "AA000000000000000000020F", "TimerControls.swift",               GRP_TIMER),
    ("AA0000000000000000000110", "AA0000000000000000000210", "TimerScreen.swift",                 GRP_TIMER),
    ("AA0000000000000000000111", "AA0000000000000000000211", "AverageSummaryView.swift",          GRP_STATS),
    ("AA0000000000000000000112", "AA0000000000000000000212", "CurrentCycleCardView.swift",        GRP_STATS),
    ("AA0000000000000000000113", "AA0000000000000000000213", "PastCycleRowView.swift",            GRP_STATS),
    ("AA0000000000000000000114", "AA0000000000000000000214", "CycleDetailView.swift",             GRP_STATS),
    ("AA0000000000000000000115", "AA0000000000000000000215", "StatsScreen.swift",                 GRP_STATS),
]

RESOURCE_FILES = [
    # (ref_id, build_id, filename, parent_group)
    ("AA0000000000000000000120", "AA0000000000000000000220", "Assets.xcassets", GRP_WORKHOUR),
]

INFOPLIST = ("AA0000000000000000000121", "Info.plist", GRP_WORKHOUR)

TEST_FILES = [
    ("AA0000000000000000000130", "AA0000000000000000000230", "TimerStoreTests.swift",           GRP_TESTS),
    ("AA0000000000000000000131", "AA0000000000000000000231", "SessionAggregationTests.swift",   GRP_TESTS),
    ("AA0000000000000000000132", "AA0000000000000000000232", "PersistenceTests.swift",          GRP_TESTS),
    ("AA0000000000000000000133", "AA0000000000000000000233", "AverageCalculationTests.swift",   GRP_TESTS),
    ("AA0000000000000000000134", "AA0000000000000000000234", "TimeFormattingTests.swift",       GRP_TESTS),
]


def filename(path):
    return path.split("/")[-1]

def build_pbxproj():
    lines = []

    def w(s=""):
        lines.append(s)

    w("// !$*UTF8*$!")
    w("{")
    w("\tarchiveVersion = 1;")
    w("\tclasses = {")
    w("\t};")
    w("\tobjectVersion = 56;")
    w("\tobjects = {")
    w()

    # ── PBXBuildFile ──────────────────────────────────────────────────────────
    w("/* Begin PBXBuildFile section */")
    for ref, bld, path, _ in APP_FILES:
        w(f"\t\t{bld} /* {filename(path)} in Sources */ = {{isa = PBXBuildFile; fileRef = {ref} /* {filename(path)} */; }};")
    for ref, bld, path, _ in RESOURCE_FILES:
        w(f"\t\t{bld} /* {filename(path)} in Resources */ = {{isa = PBXBuildFile; fileRef = {ref} /* {filename(path)} */; }};")
    for ref, bld, path, _ in TEST_FILES:
        w(f"\t\t{bld} /* {filename(path)} in Sources */ = {{isa = PBXBuildFile; fileRef = {ref} /* {filename(path)} */; }};")
    w("/* End PBXBuildFile section */")
    w()

    # ── PBXFileReference ──────────────────────────────────────────────────────
    w("/* Begin PBXFileReference section */")
    w(f"\t\t{AP} /* Hyperfocus.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = Hyperfocus.app; sourceTree = BUILT_PRODUCTS_DIR; }};")
    w(f"\t\t{TP} /* HyperfocusTests.xctest */ = {{isa = PBXFileReference; explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = HyperfocusTests.xctest; sourceTree = BUILT_PRODUCTS_DIR; }};")
    plist_ref, plist_path, _ = INFOPLIST
    w(f"\t\t{plist_ref} /* Info.plist */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Info.plist; sourceTree = \"<group>\"; }};")
    for ref, _, path, _ in APP_FILES:
        ft = "sourcecode.swift"
        w(f"\t\t{ref} /* {filename(path)} */ = {{isa = PBXFileReference; lastKnownFileType = {ft}; path = {filename(path)}; sourceTree = \"<group>\"; }};")
    for ref, _, path, _ in RESOURCE_FILES:
        ft = "folder.assetcatalog"
        w(f"\t\t{ref} /* {filename(path)} */ = {{isa = PBXFileReference; lastKnownFileType = {ft}; path = {filename(path)}; sourceTree = \"<group>\"; }};")
    for ref, _, path, _ in TEST_FILES:
        ft = "sourcecode.swift"
        w(f"\t\t{ref} /* {filename(path)} */ = {{isa = PBXFileReference; lastKnownFileType = {ft}; path = {filename(path)}; sourceTree = \"<group>\"; }};")
    w("/* End PBXFileReference section */")
    w()

    # ── PBXFrameworksBuildPhase ───────────────────────────────────────────────
    w("/* Begin PBXFrameworksBuildPhase section */")
    w(f"\t\t{APP_FW} /* Frameworks */ = {{")
    w("\t\t\tisa = PBXFrameworksBuildPhase;")
    w("\t\t\tbuildActionMask = 2147483647;")
    w("\t\t\tfiles = (")
    w("\t\t\t);")
    w("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    w("\t\t};")
    w(f"\t\t{TEST_FW} /* Frameworks */ = {{")
    w("\t\t\tisa = PBXFrameworksBuildPhase;")
    w("\t\t\tbuildActionMask = 2147483647;")
    w("\t\t\tfiles = (")
    w("\t\t\t);")
    w("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    w("\t\t};")
    w("/* End PBXFrameworksBuildPhase section */")
    w()

    # ── PBXGroup ──────────────────────────────────────────────────────────────
    w("/* Begin PBXGroup section */")

    # Main group (root = project dir = hyperfocus/)
    w(f"\t\t{MG} = {{")
    w("\t\t\tisa = PBXGroup;")
    w("\t\t\tchildren = (")
    w(f"\t\t\t\t{GRP_WORKHOUR} /* Hyperfocus */,")
    w(f"\t\t\t\t{GRP_TESTS} /* HyperfocusTests */,")
    w(f"\t\t\t\t{PG} /* Products */,")
    w("\t\t\t);")
    w("\t\t\tsourceTree = \"<group>\";")
    w("\t\t};")

    # Hyperfocus source folder group
    w(f"\t\t{GRP_WORKHOUR} /* Hyperfocus */ = {{")
    w("\t\t\tisa = PBXGroup;")
    w("\t\t\tchildren = (")
    w(f"\t\t\t\t{GRP_MODELS} /* Models */,")
    w(f"\t\t\t\t{GRP_STORES} /* Stores */,")
    w(f"\t\t\t\t{GRP_SERVICES} /* Services */,")
    w(f"\t\t\t\t{GRP_VIEWS} /* Views */,")
    w(f"\t\t\t\t{GRP_UTIL} /* Utilities */,")
    for ref, _, path, grp in APP_FILES:
        if grp == GRP_WORKHOUR:
            w(f"\t\t\t\t{ref} /* {filename(path)} */,")
    for ref, _, path, grp in RESOURCE_FILES:
        if grp == GRP_WORKHOUR:
            w(f"\t\t\t\t{ref} /* {filename(path)} */,")
    plist_ref, plist_path, _ = INFOPLIST
    w(f"\t\t\t\t{plist_ref} /* Info.plist */,")
    w("\t\t\t);")
    w("\t\t\tpath = Hyperfocus;")
    w("\t\t\tsourceTree = \"<group>\";")
    w("\t\t};")

    # Products group
    w(f"\t\t{PG} /* Products */ = {{")
    w("\t\t\tisa = PBXGroup;")
    w("\t\t\tchildren = (")
    w(f"\t\t\t\t{AP} /* Hyperfocus.app */,")
    w(f"\t\t\t\t{TP} /* HyperfocusTests.xctest */,")
    w("\t\t\t);")
    w("\t\t\tname = Products;")
    w("\t\t\tsourceTree = \"<group>\";")
    w("\t\t};")

    # Models
    w(f"\t\t{GRP_MODELS} /* Models */ = {{")
    w("\t\t\tisa = PBXGroup;")
    w("\t\t\tchildren = (")
    for ref, _, path, grp in APP_FILES:
        if grp == GRP_MODELS:
            w(f"\t\t\t\t{ref} /* {filename(path)} */,")
    w("\t\t\t);")
    w("\t\t\tpath = Models;")
    w("\t\t\tsourceTree = \"<group>\";")
    w("\t\t};")

    # Stores
    w(f"\t\t{GRP_STORES} /* Stores */ = {{")
    w("\t\t\tisa = PBXGroup;")
    w("\t\t\tchildren = (")
    for ref, _, path, grp in APP_FILES:
        if grp == GRP_STORES:
            w(f"\t\t\t\t{ref} /* {filename(path)} */,")
    w("\t\t\t);")
    w("\t\t\tpath = Stores;")
    w("\t\t\tsourceTree = \"<group>\";")
    w("\t\t};")

    # Services
    w(f"\t\t{GRP_SERVICES} /* Services */ = {{")
    w("\t\t\tisa = PBXGroup;")
    w("\t\t\tchildren = (")
    for ref, _, path, grp in APP_FILES:
        if grp == GRP_SERVICES:
            w(f"\t\t\t\t{ref} /* {filename(path)} */,")
    w("\t\t\t);")
    w("\t\t\tpath = Services;")
    w("\t\t\tsourceTree = \"<group>\";")
    w("\t\t};")

    # Views (contains Timer and Stats subgroups + top-level view files)
    w(f"\t\t{GRP_VIEWS} /* Views */ = {{")
    w("\t\t\tisa = PBXGroup;")
    w("\t\t\tchildren = (")
    w(f"\t\t\t\t{GRP_TIMER} /* Timer */,")
    w(f"\t\t\t\t{GRP_STATS} /* Stats */,")
    for ref, _, path, grp in APP_FILES:
        if grp == GRP_VIEWS:
            w(f"\t\t\t\t{ref} /* {filename(path)} */,")
    w("\t\t\t);")
    w("\t\t\tpath = Views;")
    w("\t\t\tsourceTree = \"<group>\";")
    w("\t\t};")

    # Timer subgroup
    w(f"\t\t{GRP_TIMER} /* Timer */ = {{")
    w("\t\t\tisa = PBXGroup;")
    w("\t\t\tchildren = (")
    for ref, _, path, grp in APP_FILES:
        if grp == GRP_TIMER:
            w(f"\t\t\t\t{ref} /* {filename(path)} */,")
    w("\t\t\t);")
    w("\t\t\tpath = Timer;")
    w("\t\t\tsourceTree = \"<group>\";")
    w("\t\t};")

    # Stats subgroup
    w(f"\t\t{GRP_STATS} /* Stats */ = {{")
    w("\t\t\tisa = PBXGroup;")
    w("\t\t\tchildren = (")
    for ref, _, path, grp in APP_FILES:
        if grp == GRP_STATS:
            w(f"\t\t\t\t{ref} /* {filename(path)} */,")
    w("\t\t\t);")
    w("\t\t\tpath = Stats;")
    w("\t\t\tsourceTree = \"<group>\";")
    w("\t\t};")

    # Utilities
    w(f"\t\t{GRP_UTIL} /* Utilities */ = {{")
    w("\t\t\tisa = PBXGroup;")
    w("\t\t\tchildren = (")
    for ref, _, path, grp in APP_FILES:
        if grp == GRP_UTIL:
            w(f"\t\t\t\t{ref} /* {filename(path)} */,")
    w("\t\t\t);")
    w("\t\t\tpath = Utilities;")
    w("\t\t\tsourceTree = \"<group>\";")
    w("\t\t};")

    # Tests group
    w(f"\t\t{GRP_TESTS} /* HyperfocusTests */ = {{")
    w("\t\t\tisa = PBXGroup;")
    w("\t\t\tchildren = (")
    for ref, _, path, grp in TEST_FILES:
        w(f"\t\t\t\t{ref} /* {filename(path)} */,")
    w("\t\t\t);")
    w("\t\t\tpath = HyperfocusTests;")
    w("\t\t\tsourceTree = \"<group>\";")
    w("\t\t};")

    w("/* End PBXGroup section */")
    w()

    # ── PBXNativeTarget ───────────────────────────────────────────────────────
    w("/* Begin PBXNativeTarget section */")
    # App target
    w(f"\t\t{AT} /* Hyperfocus */ = {{")
    w("\t\t\tisa = PBXNativeTarget;")
    w(f"\t\t\tbuildConfigurationList = {CL_APP} /* Build configuration list for PBXNativeTarget \"Hyperfocus\" */;")
    w("\t\t\tbuildPhases = (")
    w(f"\t\t\t\t{APP_SOURCES} /* Sources */,")
    w(f"\t\t\t\t{APP_FW} /* Frameworks */,")
    w(f"\t\t\t\t{APP_RES} /* Resources */,")
    w("\t\t\t);")
    w("\t\t\tbuildRules = (")
    w("\t\t\t);")
    w("\t\t\tdependencies = (")
    w("\t\t\t);")
    w("\t\t\tname = Hyperfocus;")
    w("\t\t\tproductName = Hyperfocus;")
    w(f"\t\t\tproductReference = {AP} /* Hyperfocus.app */;")
    w("\t\t\tproductType = \"com.apple.product-type.application\";")
    w("\t\t};")
    # Test target
    w(f"\t\t{TT} /* HyperfocusTests */ = {{")
    w("\t\t\tisa = PBXNativeTarget;")
    w(f"\t\t\tbuildConfigurationList = {CL_TEST} /* Build configuration list for PBXNativeTarget \"HyperfocusTests\" */;")
    w("\t\t\tbuildPhases = (")
    w(f"\t\t\t\t{TEST_SOURCES} /* Sources */,")
    w(f"\t\t\t\t{TEST_FW} /* Frameworks */,")
    w(f"\t\t\t\t{TEST_RES} /* Resources */,")
    w("\t\t\t);")
    w("\t\t\tbuildRules = (")
    w("\t\t\t);")
    w("\t\t\tdependencies = (")
    w("\t\t\t);")
    w("\t\t\tname = HyperfocusTests;")
    w("\t\t\tproductName = HyperfocusTests;")
    w(f"\t\t\tproductReference = {TP} /* HyperfocusTests.xctest */;")
    w("\t\t\tproductType = \"com.apple.product-type.bundle.unit-test\";")
    w("\t\t};")
    w("/* End PBXNativeTarget section */")
    w()

    # ── PBXProject ────────────────────────────────────────────────────────────
    w("/* Begin PBXProject section */")
    w(f"\t\t{P} /* Project object */ = {{")
    w("\t\t\tisa = PBXProject;")
    w("\t\t\tattributes = {")
    w("\t\t\t\tBuildIndependentTargetsInParallel = 1;")
    w(f"\t\t\t\tLastSwiftUpdateCheck = 1700;")
    w("\t\t\t\tLastUpgradeCheck = 1700;")
    w("\t\t\t\tTargetAttributes = {")
    w(f"\t\t\t\t\t{AT} = {{")
    w("\t\t\t\t\t\tCreatedOnToolsVersion = 15.0;")
    w("\t\t\t\t\t};")
    w(f"\t\t\t\t\t{TT} = {{")
    w("\t\t\t\t\t\tCreatedOnToolsVersion = 15.0;")
    w(f"\t\t\t\t\t\tTestTargetID = {AT};")
    w("\t\t\t\t\t};")
    w("\t\t\t\t};")
    w("\t\t\t};")
    w(f"\t\t\tbuildConfigurationList = {CL_PROJ} /* Build configuration list for PBXProject \"Hyperfocus\" */;")
    w("\t\t\tcompatibilityVersion = \"Xcode 14.0\";")
    w("\t\t\tdevelopmentRegion = en;")
    w("\t\t\thasScannedForEncodings = 0;")
    w("\t\t\tknownRegions = (")
    w("\t\t\t\ten,")
    w("\t\t\t\tBase,")
    w("\t\t\t);")
    w(f"\t\t\tmainGroup = {MG} /* Hyperfocus */;")
    w(f"\t\t\tproductRefGroup = {PG} /* Products */;")
    w("\t\t\tprojectDirPath = \"\";")
    w("\t\t\tprojectRoot = \"\";")
    w("\t\t\ttargets = (")
    w(f"\t\t\t\t{AT} /* Hyperfocus */,")
    w(f"\t\t\t\t{TT} /* HyperfocusTests */,")
    w("\t\t\t);")
    w("\t\t};")
    w("/* End PBXProject section */")
    w()

    # ── PBXResourcesBuildPhase ────────────────────────────────────────────────
    w("/* Begin PBXResourcesBuildPhase section */")
    w(f"\t\t{APP_RES} /* Resources */ = {{")
    w("\t\t\tisa = PBXResourcesBuildPhase;")
    w("\t\t\tbuildActionMask = 2147483647;")
    w("\t\t\tfiles = (")
    for ref, bld, path, _ in RESOURCE_FILES:
        w(f"\t\t\t\t{bld} /* {filename(path)} in Resources */,")
    w("\t\t\t);")
    w("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    w("\t\t};")
    w(f"\t\t{TEST_RES} /* Resources */ = {{")
    w("\t\t\tisa = PBXResourcesBuildPhase;")
    w("\t\t\tbuildActionMask = 2147483647;")
    w("\t\t\tfiles = (")
    w("\t\t\t);")
    w("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    w("\t\t};")
    w("/* End PBXResourcesBuildPhase section */")
    w()

    # ── PBXSourcesBuildPhase ──────────────────────────────────────────────────
    w("/* Begin PBXSourcesBuildPhase section */")
    w(f"\t\t{APP_SOURCES} /* Sources */ = {{")
    w("\t\t\tisa = PBXSourcesBuildPhase;")
    w("\t\t\tbuildActionMask = 2147483647;")
    w("\t\t\tfiles = (")
    for ref, bld, path, _ in APP_FILES:
        w(f"\t\t\t\t{bld} /* {filename(path)} in Sources */,")
    w("\t\t\t);")
    w("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    w("\t\t};")
    w(f"\t\t{TEST_SOURCES} /* Sources */ = {{")
    w("\t\t\tisa = PBXSourcesBuildPhase;")
    w("\t\t\tbuildActionMask = 2147483647;")
    w("\t\t\tfiles = (")
    for ref, bld, path, _ in TEST_FILES:
        w(f"\t\t\t\t{bld} /* {filename(path)} in Sources */,")
    w("\t\t\t);")
    w("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    w("\t\t};")
    w("/* End PBXSourcesBuildPhase section */")
    w()

    # ── XCBuildConfiguration ──────────────────────────────────────────────────
    w("/* Begin XCBuildConfiguration section */")
    for uid, name in [(CFG_PROJ_D, "Debug"), (CFG_PROJ_R, "Release")]:
        w(f"\t\t{uid} /* {name} */ = {{")
        w("\t\t\tisa = XCBuildConfiguration;")
        w("\t\t\tbuildSettings = {")
        w("\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;")
        w("\t\t\t\tCLANG_ANALYZER_NONNULL = YES;")
        w("\t\t\t\tCLANG_ANALYZER_NUMBER_OBJECT_CONVERSION = YES_AGGRESSIVE;")
        w("\t\t\t\tCLANG_CXX_LANGUAGE_STANDARD = \"gnu++20\";")
        w("\t\t\t\tCLANG_ENABLE_MODULES = YES;")
        w("\t\t\t\tCLANG_ENABLE_OBJC_ARC = YES;")
        w("\t\t\t\tCLANG_ENABLE_OBJC_WEAK = YES;")
        w("\t\t\t\tCOPY_PHASE_STRIP = NO;")
        w("\t\t\t\tDEBUG_INFORMATION_FORMAT = " + ("dwarf;" if name == "Debug" else "\"dwarf-with-dsym\";"))
        w("\t\t\t\tENABLE_STRICT_OBJC_MSGSEND = YES;")
        w("\t\t\t\tENABLE_TESTABILITY = " + ("YES;" if name == "Debug" else "NO;"))
        w("\t\t\t\tGCC_C_LANGUAGE_STANDARD = gnu17;")
        w("\t\t\t\tGCC_DYNAMIC_NO_PIC = NO;")
        w("\t\t\t\tGCC_OPTIMIZATION_LEVEL = " + ("0;" if name == "Debug" else "s;"))
        w("\t\t\t\tGCC_PREPROCESSOR_DEFINITIONS = " + ("(\"DEBUG=1\", \"$(inherited)\");" if name == "Debug" else "\"$(inherited)\";"))
        w("\t\t\t\tMACOSX_DEPLOYMENT_TARGET = 14.0;")
        w("\t\t\t\tMTL_ENABLE_DEBUG_INFO = " + ("INCLUDE_SOURCE;" if name == "Debug" else "NO;"))
        w("\t\t\t\tMTL_FAST_MATH = YES;")
        w("\t\t\t\tONLY_ACTIVE_ARCH = " + ("YES;" if name == "Debug" else "NO;"))
        w("\t\t\t\tSDKROOT = macosx;")
        w("\t\t\t\tSWIFT_ACTIVE_COMPILATION_CONDITIONS = " + ("DEBUG;" if name == "Debug" else "\"\";"))
        w("\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = " + ("\"-Onone\";" if name == "Debug" else "\"-O\";"))
        w("\t\t\t};")
        w(f"\t\t\tname = {name};")
        w("\t\t};")

    for uid, name in [(CFG_APP_D, "Debug"), (CFG_APP_R, "Release")]:
        w(f"\t\t{uid} /* {name} */ = {{")
        w("\t\t\tisa = XCBuildConfiguration;")
        w("\t\t\tbuildSettings = {")
        w("\t\t\t\tASSTESTATELOGGING_ENABLED = NO;")
        w("\t\t\t\tCOMBINE_HIDPI_IMAGES = YES;")
        w("\t\t\t\tDEAD_CODE_STRIPPING = YES;")
        w("\t\t\t\tINFOPLIST_FILE = Hyperfocus/Info.plist;")
        w("\t\t\t\tINFOPLIST_KEY_NSHumanReadableCopyright = \"\";")
        w("\t\t\t\tLE_APP_IDENTIFIER = \"com.hyperfocus.app\";")
        w("\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = \"com.hyperfocus.app\";")
        w("\t\t\t\tPRODUCT_NAME = \"$(TARGET_NAME)\";")
        w("\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;")
        w("\t\t\t\tSWIFT_VERSION = 5.9;")
        w("\t\t\t};")
        w(f"\t\t\tname = {name};")
        w("\t\t};")

    for uid, name in [(CFG_TEST_D, "Debug"), (CFG_TEST_R, "Release")]:
        w(f"\t\t{uid} /* {name} */ = {{")
        w("\t\t\tisa = XCBuildConfiguration;")
        w("\t\t\tbuildSettings = {")
        w("\t\t\t\tBUNDLE_LOADER = \"$(TEST_HOST)\";")
        w(f"\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = \"com.hyperfocus.tests\";")
        w("\t\t\t\tPRODUCT_NAME = \"$(TARGET_NAME)\";")
        w("\t\t\t\tSWIFT_VERSION = 5.9;")
        w(f"\t\t\t\tTEST_HOST = \"$(BUILT_PRODUCTS_DIR)/Hyperfocus.app/Contents/MacOS/Hyperfocus\";")
        w("\t\t\t};")
        w(f"\t\t\tname = {name};")
        w("\t\t};")

    w("/* End XCBuildConfiguration section */")
    w()

    # ── XCConfigurationList ───────────────────────────────────────────────────
    w("/* Begin XCConfigurationList section */")
    w(f"\t\t{CL_PROJ} /* Build configuration list for PBXProject \"Hyperfocus\" */ = {{")
    w("\t\t\tisa = XCConfigurationList;")
    w("\t\t\tbuildConfigurations = (")
    w(f"\t\t\t\t{CFG_PROJ_D} /* Debug */,")
    w(f"\t\t\t\t{CFG_PROJ_R} /* Release */,")
    w("\t\t\t);")
    w("\t\t\tdefaultConfigurationIsVisible = 0;")
    w("\t\t\tdefaultConfigurationName = Release;")
    w("\t\t};")
    w(f"\t\t{CL_APP} /* Build configuration list for PBXNativeTarget \"Hyperfocus\" */ = {{")
    w("\t\t\tisa = XCConfigurationList;")
    w("\t\t\tbuildConfigurations = (")
    w(f"\t\t\t\t{CFG_APP_D} /* Debug */,")
    w(f"\t\t\t\t{CFG_APP_R} /* Release */,")
    w("\t\t\t);")
    w("\t\t\tdefaultConfigurationIsVisible = 0;")
    w("\t\t\tdefaultConfigurationName = Release;")
    w("\t\t};")
    w(f"\t\t{CL_TEST} /* Build configuration list for PBXNativeTarget \"HyperfocusTests\" */ = {{")
    w("\t\t\tisa = XCConfigurationList;")
    w("\t\t\tbuildConfigurations = (")
    w(f"\t\t\t\t{CFG_TEST_D} /* Debug */,")
    w(f"\t\t\t\t{CFG_TEST_R} /* Release */,")
    w("\t\t\t);")
    w("\t\t\tdefaultConfigurationIsVisible = 0;")
    w("\t\t\tdefaultConfigurationName = Release;")
    w("\t\t};")
    w("/* End XCConfigurationList section */")
    w()

    w("\t};")
    w(f"\trootObject = {P} /* Project object */;")
    w("}")
    return "\n".join(lines)


if __name__ == "__main__":
    content = build_pbxproj()
    import os
    out = "/Users/jwchoi/Desktop/hyperfocus/Hyperfocus.xcodeproj/project.pbxproj"
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with open(out, "w") as f:
        f.write(content)
    print(f"Written: {out}")
