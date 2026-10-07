import {
  CERTIFICATE_PEEK_GAP,
  CERTIFICATE_PEEK_SIDE_SCALE,
  peekCarouselCardWidth,
} from '../../utils/CertificateTemplate';

export const PEEK_CAROUSEL_SNAP_THRESHOLD: number = 0.28;

export function peekCarouselCardHeight(viewportWidth: number, aspectRatio: number): number {
  const cardW = peekCarouselCardWidth(viewportWidth > 0 ? viewportWidth : 390);
  return Math.round(cardW * aspectRatio);
}

export function peekCarouselPeekMargin(viewportWidth: number): number {
  const w = viewportWidth > 0 ? viewportWidth : 390;
  const cardW = peekCarouselCardWidth(w);
  return Math.max(0, (w - cardW) / 2);
}

export function peekCarouselPageStride(viewportWidth: number): number {
  return peekCarouselCardWidth(viewportWidth > 0 ? viewportWidth : 390) + CERTIFICATE_PEEK_GAP;
}

export function peekCarouselTrackOffset(progress: number, viewportWidth: number): number {
  return -progress * peekCarouselPageStride(viewportWidth);
}

export function peekCarouselScaleFor(index: number, progress: number): number {
  const distance = Math.min(1, Math.abs(progress - index));
  return CERTIFICATE_PEEK_SIDE_SCALE + (1 - CERTIFICATE_PEEK_SIDE_SCALE) * (1 - distance);
}

export function peekCarouselScaleAnchorX(index: number, progress: number): string {
  const diff = index - progress;
  if (diff < -0.02) {
    return '100%';
  }
  if (diff > 0.02) {
    return '0%';
  }
  return '50%';
}

export function peekCarouselZIndexFor(index: number, progress: number): number {
  const distance = Math.abs(progress - index);
  return Math.round(10 - Math.min(9, distance * 9));
}

export function peekCarouselSnapTargetIndex(
  progress: number,
  maxIndex: number,
  panStartProgress: number,
  velocityX: number,
): number {
  const max = Math.max(0, maxIndex);
  const clamped = Math.max(0, Math.min(max, progress));
  if (clamped <= 0) {
    return 0;
  }
  if (clamped >= max) {
    return max;
  }

  const flickVpPerSec = 380;
  if (velocityX <= -flickVpPerSec) {
    return Math.min(max, Math.ceil(clamped));
  }
  if (velocityX >= flickVpPerSec) {
    return Math.max(0, Math.floor(clamped));
  }

  const base = Math.floor(clamped);
  const frac = clamped - base;
  if (frac < PEEK_CAROUSEL_SNAP_THRESHOLD) {
    return base;
  }
  if (frac > 1 - PEEK_CAROUSEL_SNAP_THRESHOLD) {
    return Math.min(max, base + 1);
  }
  if (progress < panStartProgress) {
    return base;
  }
  if (progress > panStartProgress) {
    return Math.min(max, base + 1);
  }
  return Math.round(clamped);
}
