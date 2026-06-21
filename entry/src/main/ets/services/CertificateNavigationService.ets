import {
  HonorCertificateData,
  ShameCertificateData
} from '../models/CertificateModel';
import { PageRoutes, pushRoute } from '../router/PageRoutes';
import { StoreKeys } from '../stores/StoreKeys';
import { bootstrapStores } from '../stores/StoreBootstrap';

bootstrapStores();

function syncStorageValue<T>(key: string, value: T): void {
  if (!AppStorage.set<T>(key, value)) {
    AppStorage.setOrCreate<T>(key, value);
  }
}

export function openHonorCertificatePreview(data: HonorCertificateData): void {
  syncStorageValue<string>(StoreKeys.CertificateKind, 'honor');
  syncStorageValue<HonorCertificateData>(StoreKeys.CertificateHonor, data);
  pushRoute(PageRoutes.CertificatePreview);
}

export function openShameCertificatePreview(data: ShameCertificateData): void {
  syncStorageValue<string>(StoreKeys.CertificateKind, 'shame');
  syncStorageValue<ShameCertificateData>(StoreKeys.CertificateShame, data);
  pushRoute(PageRoutes.CertificatePreview);
}
