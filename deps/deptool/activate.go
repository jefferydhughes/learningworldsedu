package deptool

import (
	"fmt"
	"os"
	"path/filepath"
)

const (
	// Name of the symlink to the active dependency version
	ACTIVE_DEPENDENCY_SYMLINK_NAME = "_active_"
)

func ActivateDependency(depsDirPath, depName, version, platform string) error {
	var err error

	// path to the dependency to activate
	depDirPath := filepath.Join(depsDirPath, depName)
	depVersionDirPath := filepath.Join(depDirPath, version)
	depPlatformArchivePath := filepath.Join(depVersionDirPath, "prebuilt", platform+".tar.gz")
	depPlatformChecksumPath := depPlatformArchivePath + ".sha256"
	// _active_
	activeDirPath := filepath.Join(depDirPath, ACTIVE_DEPENDENCY_SYMLINK_NAME)
	activePlatformDirPath := filepath.Join(activeDirPath, "prebuilt", platform)
	activeChecksumPath := filepath.Join(activePlatformDirPath, "checksum.sha256")

	// check if the dependency directory exists
	if _, err := os.Stat(depDirPath); os.IsNotExist(err) {
		return fmt.Errorf("dependency directory doesn't exist: %s", depDirPath)
	}

	// check if the dependency version directory exists
	if _, err := os.Stat(depVersionDirPath); os.IsNotExist(err) {
		// TODO: try to download the dependency
		return fmt.Errorf("dependency version directory doesn't exist: %s", depVersionDirPath)
	}

	// check if the dependency platform archive exists
	if _, err := os.Stat(depPlatformArchivePath); os.IsNotExist(err) {
		return fmt.Errorf("dependency platform archive doesn't exist: %s", depPlatformArchivePath)
	}

	// check if the dependency platform checksum exists
	if _, err := os.Stat(depPlatformChecksumPath); os.IsNotExist(err) {
		return fmt.Errorf("dependency platform checksum doesn't exist: %s", depPlatformChecksumPath)
	}

	// Read the checksum value from the file
	checksum, err := os.ReadFile(depPlatformChecksumPath)
	if err != nil {
		return fmt.Errorf("failed to read checksum: %w", err)
	}

	// check if the active directory exists and already contains the correct version
	if info, err := os.Stat(activeDirPath); err == nil && info.IsDir() {
		// make sure the checksum file exists
		if info, err := os.Stat(activeChecksumPath); err == nil && !info.IsDir() {
			// read the checksum value from the file
			activeChecksum, err := os.ReadFile(activeChecksumPath)
			if err == nil {
				// compare the checksums
				if string(checksum) == string(activeChecksum) {
					fmt.Printf("✅ dependency [%s][%s] already activated\n", depName, version)
					return nil // success
				}
			}
		}
	}

	// dependency needs to be activated

	// remove existing "active" copy if it exists
	if _, err := os.Stat(activePlatformDirPath); err == nil {
		err = os.RemoveAll(activePlatformDirPath) // Use RemoveAll to handle non-empty directories
		if err != nil {
			return fmt.Errorf("failed to remove existing _active_ for platform %s: %w", platform, err)
		}
	}

	// create a fresh "active" directory
	err = os.MkdirAll(activePlatformDirPath, 0755)
	if err != nil {
		return fmt.Errorf("failed to create _active_ directory: %w", err)
	}

	// un-archive the dependency platform archive
	{
		archiveFile, err := os.Open(depPlatformArchivePath)
		if err != nil {
			return fmt.Errorf("failed to open dependency platform archive: %w", err)
		}
		defer archiveFile.Close()

		err = UnarchiveTarGz(archiveFile, activePlatformDirPath)
		if err != nil {
			return fmt.Errorf("failed to un-archive dependency platform archive: %w", err)
		}
	}

	// write a checksum in the active directory
	{
		err = os.WriteFile(activeChecksumPath, []byte(checksum), 0644)
		if err != nil {
			return fmt.Errorf("failed to write active checksum: %w", err)
		}
	}

	return nil // success
}
