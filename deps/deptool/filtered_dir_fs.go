package deptool

import (
	"errors"
	"io/fs"
	"os"
	"slices"
)

// Note: this could become an open source Go module

//
// FilteredDirFS is a modified implementation of os.DirFS that filters out
// files with the given filenames.
//

// DirFS returns a file system (an fs.FS) for the tree of files rooted at the directory dir.
//
// Note that DirFS("/prefix") only guarantees that the Open calls it makes to the
// operating system will begin with "/prefix": DirFS("/prefix").Open("file") is the
// same as os.Open("/prefix/file"). So if /prefix/file is a symbolic link pointing outside
// the /prefix tree, then using DirFS does not stop the access any more than using
// os.Open does. Additionally, the root of the fs.FS returned for a relative path,
// DirFS("prefix"), will be affected by later calls to Chdir. DirFS is therefore not
// a general substitute for a chroot-style security mechanism when the directory tree
// contains arbitrary content.
//
// Use [Root.FS] to obtain a fs.FS that prevents escapes from the tree via symbolic links.
//
// The directory dir must not be "".
//
// The result implements [io/fs.StatFS], [io/fs.ReadFileFS] and
// [io/fs.ReadDirFS].
func FilteredDirFS(dir string, excludedFilenames []string) fs.FS {
	return &filteredDirFS{
		dir:               dir,
		excludedFilenames: excludedFilenames,
	}
}

type filteredDirFS struct {
	dir               string
	excludedFilenames []string
}

func (dir filteredDirFS) Open(name string) (fs.File, error) {
	fullname, err := dir.join(name)
	if err != nil {
		return nil, &os.PathError{Op: "open", Path: name, Err: err}
	}
	f, err := os.Open(fullname)
	if err != nil {
		// DirFS takes a string appropriate for GOOS,
		// while the name argument here is always slash separated.
		// dir.join will have mixed the two; undo that for
		// error reporting.
		err.(*os.PathError).Path = name
		return nil, err
	}
	return f, nil
}

// The ReadFile method calls the [ReadFile] function for the file
// with the given name in the directory. The function provides
// robust handling for small files and special file systems.
// Through this method, dirFS implements [io/fs.ReadFileFS].
func (dir filteredDirFS) ReadFile(name string) ([]byte, error) {
	fullname, err := dir.join(name)
	if err != nil {
		return nil, &os.PathError{Op: "readfile", Path: name, Err: err}
	}
	b, err := os.ReadFile(fullname)
	if err != nil {
		if e, ok := err.(*os.PathError); ok {
			// See comment in dirFS.Open.
			e.Path = name
		}
		return nil, err
	}
	return b, nil
}

// ReadDir reads the named directory, returning all its directory entries sorted
// by filename. Through this method, dirFS implements [io/fs.ReadDirFS].
func (dir filteredDirFS) ReadDir(name string) ([]os.DirEntry, error) {
	fullname, err := dir.join(name)
	if err != nil {
		return nil, &os.PathError{Op: "readdir", Path: name, Err: err}
	}
	entries, err := os.ReadDir(fullname)
	if err != nil {
		if e, ok := err.(*os.PathError); ok {
			// See comment in dirFS.Open.
			e.Path = name
		}
		return nil, err
	}

	// Filter out the excluded filenames
	filteredEntries := []os.DirEntry{}
	for _, entry := range entries {
		if slices.Contains(dir.excludedFilenames, entry.Name()) {
			continue
		}
		filteredEntries = append(filteredEntries, entry)
	}

	return filteredEntries, nil
}

func (dir filteredDirFS) Stat(name string) (fs.FileInfo, error) {
	fullname, err := dir.join(name)
	if err != nil {
		return nil, &os.PathError{Op: "stat", Path: name, Err: err}
	}
	f, err := os.Stat(fullname)
	if err != nil {
		// See comment in dirFS.Open.
		err.(*os.PathError).Path = name
		return nil, err
	}
	return f, nil
}

// join returns the path for name in dir.
func (fs filteredDirFS) join(name string) (string, error) {
	if fs.dir == "" {
		return "", errors.New("os: DirFS with empty root")
	}
	//
	// NOTE: I commented this block because it doesn't compile and I am not sure how to fix it
	//
	// name, err := filepathlite.Localize(name)
	// if err != nil {
	// 	return "", os.ErrInvalid
	// }
	if os.IsPathSeparator(fs.dir[len(fs.dir)-1]) {
		return string(fs.dir) + name, nil
	}
	return string(fs.dir) + string(os.PathSeparator) + name, nil
}
