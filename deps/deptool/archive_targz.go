package deptool

import (
	"archive/tar"
	"compress/gzip"
	"fmt"
	"io"
	"io/fs"
	"os"
	"path/filepath"
)

// Documentation:
// https://www.arthurkoziel.com/writing-tar-gz-files-in-go/

// Note: this could become an open source Go module

// TODO: Implement this

func WriteTarGz(w io.WriteCloser, fsys fs.FS) error {

	// Create a new tar.gz writer
	gzw := gzip.NewWriter(w)
	defer gzw.Close()

	// Create a new tar writer
	tw := tar.NewWriter(gzw)
	defer tw.Close()

	err := tw.AddFS(fsys)

	return err
}

func UnarchiveTarGz(r io.Reader, destPath string) error {

	// make sure the destination directory exists
	_, err := os.Stat(destPath)
	if err != nil {
		return err
	}

	gzr, err := gzip.NewReader(r)
	if err != nil {
		return err
	}
	defer gzr.Close()

	tr := tar.NewReader(gzr)

	for {
		hdr, err := tr.Next()
		if err == io.EOF {
			break
		}
		if err != nil {
			return err
		}

		filepath := filepath.Join(destPath, hdr.Name)
		// fmt.Println("filepath ->", filepath)

		// create the directory
		if hdr.Typeflag == tar.TypeDir {
			err = os.MkdirAll(filepath, 0755)
			if err != nil {
				return err
			}
		} else if hdr.Typeflag == tar.TypeReg {
			// create the file
			file, err := os.Create(filepath)
			if err != nil {
				return err
			}
			defer file.Close()

			// copy the file content
			_, err = io.Copy(file, tr)
			if err != nil {
				return err
			}
		} else {
			return fmt.Errorf("unknown file type: %d", hdr.Typeflag)
		}
	}

	return nil // success
}
