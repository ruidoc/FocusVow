import { QuickTask, QuickTaskUpsertPayload } from '../models/QuickTaskModel';
import { ApiEnvelope } from '../models/UserModel';
import { QuickTaskApiService } from '../services/QuickTaskApiService';
import { bootstrapStores } from './StoreBootstrap';
import { StoreKeys } from './StoreKeys';
import { UserStore } from './UserStore';

function syncAppStorageValue<T>(key: string, value: T): void {
  if (!AppStorage.set<T>(key, value)) {
    AppStorage.setOrCreate<T>(key, value);
  }
}

export class QuickTaskStore {
  static hydrate(): void {
    bootstrapStores();
  }

  static getTasks(): QuickTask[] {
    QuickTaskStore.hydrate();
    return AppStorage.get<QuickTask[]>(StoreKeys.QuickTaskList) ?? [];
  }

  static setTasks(tasks: QuickTask[]): void {
    QuickTaskStore.hydrate();
    syncAppStorageValue(StoreKeys.QuickTaskList, tasks);
  }

  static markDirty(): void {
    QuickTaskStore.hydrate();
    syncAppStorageValue(StoreKeys.QuickTaskDirty, true);
  }

  static clearDirty(): void {
    syncAppStorageValue(StoreKeys.QuickTaskDirty, false);
  }

  static isDirty(): boolean {
    QuickTaskStore.hydrate();
    return AppStorage.get<boolean>(StoreKeys.QuickTaskDirty) === true;
  }

  static setLoading(loading: boolean): void {
    syncAppStorageValue(StoreKeys.QuickTaskLoading, loading);
  }

  static isLoading(): boolean {
    QuickTaskStore.hydrate();
    return AppStorage.get<boolean>(StoreKeys.QuickTaskLoading) === true;
  }

  static clearTasks(): void {
    QuickTaskStore.hydrate();
    syncAppStorageValue(StoreKeys.QuickTaskList, []);
    syncAppStorageValue(StoreKeys.QuickTaskDirty, false);
    syncAppStorageValue(StoreKeys.QuickTaskLoading, false);
  }

  static titleExists(title: string, excludeId: string = ''): boolean {
    const name = title.trim();
    return QuickTaskStore.getTasks().some((item: QuickTask) =>
      item.title.trim() === name && item.id !== excludeId);
  }

  static async loadAll(): Promise<ApiEnvelope> {
    if (!UserStore.isLoggedIn()) {
      QuickTaskStore.clearTasks();
      return { statusCode: 401, message: '未登录' };
    }
    QuickTaskStore.setLoading(true);
    try {
      const response = await QuickTaskApiService.list();
      if (response.statusCode === 200) {
        QuickTaskStore.setTasks(QuickTaskApiService.parseList(response));
        QuickTaskStore.clearDirty();
      }
      return response;
    } finally {
      QuickTaskStore.setLoading(false);
    }
  }

  static async syncOnVisible(): Promise<void> {
    if (!UserStore.isLoggedIn() || QuickTaskStore.isLoading()) {
      return;
    }
    if (QuickTaskStore.isDirty() || QuickTaskStore.getTasks().length === 0) {
      await QuickTaskStore.loadAll();
    }
  }

  static async createTask(payload: QuickTaskUpsertPayload): Promise<ApiEnvelope> {
    const response = await QuickTaskApiService.add(payload);
    if (response.statusCode === 200) {
      const task = QuickTaskApiService.parseTask(response);
      if (task) {
        QuickTaskStore.setTasks([task, ...QuickTaskStore.getTasks()]);
      }
    }
    return response;
  }

  static async updateTask(id: string, payload: QuickTaskUpsertPayload): Promise<ApiEnvelope> {
    const response = await QuickTaskApiService.edit(id, payload);
    if (response.statusCode === 200) {
      const task = QuickTaskApiService.parseTask(response);
      if (task) {
        QuickTaskStore.setTasks(
          QuickTaskStore.getTasks().map((item: QuickTask) => item.id === id ? task : item)
        );
      }
    }
    return response;
  }

  static async removeTask(id: string): Promise<ApiEnvelope> {
    const response = await QuickTaskApiService.remove(id);
    if (response.statusCode === 200) {
      QuickTaskStore.setTasks(QuickTaskStore.getTasks().filter((item: QuickTask) => item.id !== id));
    }
    return response;
  }
}
