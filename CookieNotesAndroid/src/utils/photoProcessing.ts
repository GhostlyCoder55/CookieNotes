import { Image } from 'react-native';
import { Directory, File, Paths } from 'expo-file-system';
import { manipulateAsync, SaveFormat } from 'expo-image-manipulator';
import { generateUUID } from './uuid';

export const FULL_PHOTO_MAX_EDGE = 1600;
export const THUMBNAIL_MAX_EDGE = 480;

export interface StoredPhotoPaths {
  imageUri: string;
  thumbnailUri: string;
}

function getPhotosDirectory(): Directory {
  const dir = new Directory(Paths.document, 'photos');
  if (!dir.exists) {
    dir.create({ intermediates: true, idempotent: true });
  }
  return dir;
}

function getImageDimensions(uri: string): Promise<{ width: number; height: number } | null> {
  return new Promise((resolve) => {
    Image.getSize(
      uri,
      (width, height) => resolve({ width, height }),
      () => resolve(null)
    );
  });
}

async function downsampleAndSaveJpeg(
  sourceUri: string,
  maxEdge: number,
  compress: number,
  destFile: File
): Promise<boolean> {
  try {
    const dims = await getImageDimensions(sourceUri);
    const actions = [];
    if (dims && Math.max(dims.width, dims.height) > maxEdge) {
      if (dims.width >= dims.height) {
        actions.push({ resize: { width: maxEdge } });
      } else {
        actions.push({ resize: { height: maxEdge } });
      }
    }

    const result = await manipulateAsync(sourceUri, actions, {
      compress,
      format: SaveFormat.JPEG,
    });

    const tempFile = new File(result.uri);
    if (!tempFile.exists) return false;
    tempFile.copySync(destFile);
    try {
      if (tempFile.uri !== destFile.uri && tempFile.exists) {
        tempFile.delete();
      }
    } catch {
      // Ignore cleanup errors on cache files
    }
    return destFile.exists;
  } catch {
    return false;
  }
}

export async function processAndSavePhotoFromUri(
  sourceUri: string
): Promise<StoredPhotoPaths | null> {
  if (!sourceUri) return null;
  try {
    const photosDir = getPhotosDirectory();
    const id = generateUUID();
    const fullFile = new File(photosDir, `${id}_full.jpg`);
    const thumbFile = new File(photosDir, `${id}_thumb.jpg`);

    const fullOk = await downsampleAndSaveJpeg(sourceUri, FULL_PHOTO_MAX_EDGE, 0.82, fullFile);
    if (!fullOk) return null;

    const thumbOk = await downsampleAndSaveJpeg(fullFile.uri, THUMBNAIL_MAX_EDGE, 0.72, thumbFile);
    if (!thumbOk) {
      deletePhotoFiles({ imageUri: fullFile.uri, thumbnailUri: '' });
      return null;
    }

    return {
      imageUri: fullFile.uri,
      thumbnailUri: thumbFile.uri,
    };
  } catch {
    return null;
  }
}

export async function downloadAndSaveRemotePhoto(url: string): Promise<StoredPhotoPaths | null> {
  const trimmed = url.trim();
  if (!trimmed) return null;
  let tempFile: File | null = null;
  try {
    const tempName = `dl_${generateUUID()}.img`;
    const target = new File(Paths.cache, tempName);
    const downloaded = await File.downloadFileAsync(trimmed, target, { idempotent: true });
    tempFile = downloaded;
    if (!downloaded.exists) return null;
    return await processAndSavePhotoFromUri(downloaded.uri);
  } catch {
    return null;
  } finally {
    if (tempFile && tempFile.exists) {
      try {
        tempFile.delete();
      } catch {
        // Ignore temp file deletion error
      }
    }
  }
}

export function deletePhotoFiles(photo: Pick<StoredPhotoPaths, 'imageUri' | 'thumbnailUri'>): void {
  const uris = [photo.imageUri, photo.thumbnailUri].filter((u) => Boolean(u));
  for (const uri of uris) {
    try {
      const file = new File(uri);
      if (file.exists) {
        file.delete();
      }
    } catch {
      // Ignore missing or read-only file errors during cleanup
    }
  }
}
