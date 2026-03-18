package deptool

import (
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
)

func UploadArtifacts(objectStorageBuildFunc ObjectStorageBuildFunc, depsDirPath, depName, version, platform string) error {
	fmt.Printf("⭐️ Uploading artifacts for [%s] [%s] [%s]\n", depName, version, platform)

	// Validate arguments

	if !isDependencyNameValid(depName) {
		return fmt.Errorf("invalid dependency name: %s", depName)
	}

	if !isPlatformNameValid(platform) {
		return fmt.Errorf("invalid platform name: %s", platform)
	}

	if version == "" {
		return fmt.Errorf("version is required")
	}

	// Construct the list of artifacts paths to upload
	depsPathsToUpload := []string{}
	if platform == PlatformAll {
		for _, supportedPlatform := range supportedPlatforms {
			depsPathsToUpload = append(depsPathsToUpload, constructDepArtifactsPath(depName, version, supportedPlatform))
		}
	} else {
		depsPathsToUpload = append(depsPathsToUpload, constructDepArtifactsPath(depName, version, platform))
	}

	// Construct the object storage client
	objectStorage, err := objectStorageBuildFunc()
	if err != nil {
		return fmt.Errorf("failed to build object storage client: %w", err)
	}

	// Try to upload each path (each path is for a specific platform)
	// <depPath> value examples:
	// - libpng/1.6.48/prebuilt/android
	// - libpng/1.6.48/prebuilt/source
	for _, depPlatformPath := range depsPathsToUpload {
		depPlatformPath = filepath.Join(depsDirPath, depPlatformPath)

		// Make sure the dependency name exists
		if _, err := os.Stat(depPlatformPath); os.IsNotExist(err) {
			fmt.Printf("-> Path does not exist. Skipping. %s\n", depPlatformPath)
			continue
		}

		archivePath := filepath.Join(depsDirPath, depName, version, "prebuilt", platform+".tar.gz")
		checksumPath := archivePath + ".sha256"

		// Create a tar.gz archive
		{
			// Create the tar.gz archive file
			archiveFile, err := os.Create(archivePath)
			if err != nil {
				return fmt.Errorf("failed to create archive: %w", err)
			}
			defer archiveFile.Close()

			// Create the filesystem to archive
			fsys := FilteredDirFS(depPlatformPath, []string{".DS_Store"})

			// Create the tar.gz archive
			err = WriteTarGz(archiveFile, fsys)
			if err != nil {
				return fmt.Errorf("failed to create archive: %w", err)
			}
		}

		// Create the checksum file
		{
			// open the archive file
			archiveFile, err := os.Open(archivePath)
			if err != nil {
				return fmt.Errorf("failed to open archive: %w", err)
			}
			defer archiveFile.Close()

			// Create a SHA-256 hash
			hash := sha256.New()
			if _, err := io.Copy(hash, archiveFile); err != nil {
				return fmt.Errorf("failed to compute checksum: %w", err)
			}
			hashSum := hex.EncodeToString(hash.Sum(nil)) // hex string

			// create the checksum file
			checksumFile, err := os.Create(checksumPath)
			if err != nil {
				return fmt.Errorf("failed to create checksum file: %w", err)
			}
			defer checksumFile.Close()

			// Write the hash to the checksum file
			if _, err := checksumFile.WriteString(hashSum); err != nil {
				return fmt.Errorf("failed to write checksum: %w", err)
			}
		}

		// Upload the archive to object storage
		{
			// open the archive file
			archiveFile, err := os.Open(archivePath)
			if err != nil {
				return fmt.Errorf("failed to open archive: %w", err)
			}
			defer archiveFile.Close()

			// Construct the S3 object storage key
			objectStorageKey, err := filepath.Rel(depsDirPath, archivePath)
			if err != nil {
				return fmt.Errorf("failed to get relative path: %w", err)
			}

			// Enforce / separator (even on Windows)
			objectStorageKey = strings.ReplaceAll(objectStorageKey, `\`, `/`)

			// Split path into elements and remove "prebuilt" if it's the 3rd element
			pathElements := strings.Split(objectStorageKey, "/")
			if len(pathElements) >= 3 && pathElements[2] == "prebuilt" {
				pathElements = append(pathElements[:2], pathElements[3:]...)
				objectStorageKey = strings.Join(pathElements, "/")
			}

			err = objectStorage.Upload(objectStorageKey, archiveFile)
			if err != nil {
				return fmt.Errorf("failed to upload archive: %w", err)
			}
		}

		// Upload the checksum to object storage
		{
			// open the archive file
			file, err := os.Open(checksumPath)
			if err != nil {
				return fmt.Errorf("failed to open checksum file: %w", err)
			}
			defer file.Close()

			// Construct the S3 object storage key
			objectStorageKey, err := filepath.Rel(depsDirPath, checksumPath)
			if err != nil {
				return fmt.Errorf("failed to get relative path: %w", err)
			}

			// Enforce / separator (even on Windows)
			objectStorageKey = strings.ReplaceAll(objectStorageKey, `\`, `/`)

			// Split path into elements and remove "prebuilt" if it's the 3rd element
			pathElements := strings.Split(objectStorageKey, "/")
			if len(pathElements) >= 3 && pathElements[2] == "prebuilt" {
				pathElements = append(pathElements[:2], pathElements[3:]...)
				objectStorageKey = strings.Join(pathElements, "/")
			}

			err = objectStorage.Upload(objectStorageKey, file)
			if err != nil {
				return fmt.Errorf("failed to upload archive: %w", err)
			}
		}
	}

	fmt.Println("✅ Successfully uploaded all files")

	return nil
}
