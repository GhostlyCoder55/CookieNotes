import type { AdFeedBlock, AdSlot } from '../types/models';

export function browsingSlots(
  itemCount: number,
  adsEnabled: boolean,
  chunkSize = 6,
  maxAds = 2
): AdSlot[] {
  if (itemCount <= 0) return [];

  const slots: AdSlot[] = [];
  let adsInserted = 0;
  let adIndex = 0;
  let index = 0;

  while (index < itemCount) {
    const end = Math.min(index + chunkSize, itemCount);
    for (let offset = index; offset < end; offset += 1) {
      slots.push({ kind: 'item', index: offset });
    }
    const moreRemain = end < itemCount;
    if (adsEnabled && moreRemain && adsInserted < maxAds) {
      slots.push({ kind: 'advertisement', adIndex });
      adIndex += 1;
      adsInserted += 1;
    }
    index = end;
  }

  if (adsEnabled && adsInserted === 0) {
    slots.push({ kind: 'advertisement', adIndex });
  }

  return slots;
}

export function searchSlots(itemCount: number, adsEnabled: boolean): AdSlot[] {
  if (itemCount <= 0) return [];

  const slots: AdSlot[] = [];
  for (let index = 0; index < itemCount; index += 1) {
    slots.push({ kind: 'item', index });
    const afterFourthResult = index === 3;
    const afterShortList = itemCount < 4 && index === itemCount - 1;
    if (adsEnabled && (afterFourthResult || afterShortList)) {
      slots.push({ kind: 'advertisement', adIndex: 0 });
    }
  }
  return slots;
}

export function blocksFromSlots(slots: readonly AdSlot[]): AdFeedBlock[] {
  const blocks: AdFeedBlock[] = [];
  let pending: number[] = [];
  let nextID = 0;

  const flushItems = () => {
    if (pending.length === 0) return;
    const blockID = nextID * 1000 + (pending[0] ?? 0);
    blocks.push({ id: blockID, kind: 'items', indices: pending });
    nextID += 1;
    pending = [];
  };

  for (const slot of slots) {
    if (slot.kind === 'item') {
      pending.push(slot.index);
    } else {
      flushItems();
      blocks.push({ id: nextID * 1000 + 900, kind: 'advertisement' });
      nextID += 1;
    }
  }
  flushItems();
  return blocks;
}

export function showsContentBanner(adsEnabled: boolean, hasContent: boolean): boolean {
  return adsEnabled && hasContent;
}
