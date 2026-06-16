export const ping: () => string;
export const prepareConfig: (subscriptionUrl: string, rawContent: string) => string;
export const startProxy: (configPath: string) => string;
export const stopProxy: () => string;
export const getStatus: () => string;
export const checkPort: (port: number) => number;
