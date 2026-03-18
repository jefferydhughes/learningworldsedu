package deptool

import (
	"fmt"
	"os"
	"path/filepath"
	"slices"
)

const ( // Supported dependencies
	DependencyLibluau = "libluau"
	DependencyLibpng  = "libpng"
	DependencyLibjolt = "libjolt"

	// Supported platforms
	PlatformAll     = "all"
	PlatformSource  = "source"
	PlatformAndroid = "android"
	PlatformIOS     = "ios"
	PlatformMacos   = "macos"
	PlatformWindows = "windows"
	PlatformLinux   = "linux"
)

var (
	supportedDependencies = []string{DependencyLibluau, DependencyLibpng, DependencyLibjolt}
	supportedPlatforms    = []string{PlatformSource, PlatformAndroid, PlatformIOS, PlatformMacos, PlatformWindows, PlatformLinux}
)

func isDependencyNameValid(name string) bool {
	return slices.Contains(supportedDependencies, name)
}

func isPlatformNameValid(name string) bool {
	return slices.Contains(supportedPlatforms, name) || name == PlatformAll
}

func constructDepArtifactsPath(depName, version, platform string) string {
	return filepath.Join(depName, version, "prebuilt", platform)
}

func constructDepArtifactsArchivePath(depName, version, platform string) string {
	return constructDepArtifactsPath(depName, version, platform) + ".tar.gz"
}

// Check if a dependency is installed
//
// Return values:
// - string: the full path to the dependency files
// - bool: whether the dependency is installed
// - error
func areDependencyFilesInstalled(depsDirPath, depName, version, platform string) (string, bool, error) {
	// fullDepPath is like: [...]/cubzh/deps/libpng/1.6.47/prebuilt/macos.tar.gz
	fullDepPath := filepath.Join(depsDirPath, constructDepArtifactsArchivePath(depName, version, platform))
	fullDepPathChecksum := fullDepPath + ".sha256"

	// check if the directory exists
	_, err := os.Stat(fullDepPath)
	if err != nil {
		if os.IsNotExist(err) {
			// directory does not exist
			return fullDepPath, false, nil
		}
		// error
		return "", false, fmt.Errorf("failed to check if directory exists: %w", err)
	}

	// check if the checksum file exists
	_, err = os.Stat(fullDepPathChecksum)
	if err != nil {
		if os.IsNotExist(err) {
			// checksum file does not exist
			return fullDepPath, false, nil
		}
		// error
		return "", false, fmt.Errorf("failed to check if checksum file exists: %w", err)
	}

	return fullDepPath, true, nil
}
