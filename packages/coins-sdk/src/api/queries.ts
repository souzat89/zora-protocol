import {
  GetCoinCommentsData,
  GetCoinCommentsResponse,
  GetCoinData,
  GetCoinResponse,
  GetCoinsData,
  GetCoinsResponse,
  GetProfileBalancesData,
  GetProfileBalancesResponse,
  GetProfileCoinsData,
  GetProfileCoinsResponse,
  GetProfileData,
  GetProfileResponse,
} from "../client/types.gen";
import {
  getCoin as getCoinSDK,
  getCoins as getCoinsSDK,
  getCoinComments as getCoinCommentsSDK,
  getProfile as getProfileSDK,
  getProfileBalances as getProfileBalancesSDK,
  getProfileCoins as getProfileCoinsSDK,
} from "../client/sdk.gen";
import { getApiKeyMeta } from "./api-key";
import { RequestOptionsType } from "./query-types";
import { RequestResult } from "@hey-api/client-fetch";

export type { RequestResult };

type GetCoinQuery = GetCoinData["query"];
export type { GetCoinQuery, GetCoinData };
export type { GetCoinResponse } from "../client/types.gen";

export type CoinData = NonNullable<GetCoinResponse["zora20Token"]>;

export const getCoin = async (
  query: GetCoinQuery,
  options?: RequestOptionsType<GetCoinData>,
): Promise<RequestResult<GetCoinResponse>> => {
  return await getCoinSDK({
    ...options,
    query,
    ...getApiKeyMeta(),
  });
};

type GetCoinsQuery = GetCoinsData["query"];
export type { GetCoinsQuery, GetCoinsData };
export type { GetCoinsResponse } from "../client/types.gen";

export const getCoins = async (
  query: GetCoinsQuery,
  options?: RequestOptionsType<GetCoinsData>,
): Promise<RequestResult<GetCoinsResponse>> => {
  return await getCoinsSDK({
    query: {
      coins: query.coins.map((coinData) => JSON.stringify(coinData)) as any,
    },
    ...getApiKeyMeta(),
    ...options,
  });
};

type GetCoinCommentsQuery = GetCoinCommentsData["query"];
export type { GetCoinCommentsQuery, GetCoinCommentsData };
export type { GetCoinCommentsResponse } from "../client/types.gen";

export const getCoinComments = async (
  query: GetCoinCommentsQuery,
  options?: RequestOptionsType<GetCoinCommentsData>,
): Promise<RequestResult<GetCoinCommentsResponse>> => {
  return await getCoinCommentsSDK({
    query,
    ...getApiKeyMeta(),
    ...options,
  });
};

type GetProfileQuery = GetProfileData["query"];
export type { GetProfileQuery, GetProfileData };
export type { GetProfileResponse } from "../client/types.gen";

export const getProfile = async (
  query: GetProfileQuery,
  options?: RequestOptionsType<GetProfileData>,
): Promise<RequestResult<GetProfileResponse>> => {
  return await getProfileSDK({
    query,
    ...getApiKeyMeta(),
    ...options,
  });
};

type GetProfileCoinsQuery = GetProfileCoinsData["query"];
export type { GetProfileCoinsQuery, GetProfileCoinsData };
export type { GetProfileCoinsResponse } from "../client/types.gen";

export const getProfileCoins = async (
  query: GetProfileCoinsQuery,
  options?: RequestOptionsType<GetProfileCoinsData>,
): Promise<RequestResult<GetProfileCoinsResponse>> => {
  return await getProfileCoinsSDK({
    query,
    ...getApiKeyMeta(),
    ...options,
  });
};

type GetProfileBalancesQuery = GetProfileBalancesData["query"];
export type { GetProfileBalancesQuery, GetProfileBalancesData };
export type { GetProfileBalancesResponse } from "../client/types.gen";

export const getProfileBalances = async (
  query: GetProfileBalancesQuery,
  options?: RequestOptionsType<GetProfileBalancesData>,
): Promise<RequestResult<GetProfileBalancesResponse>> => {
  return await getProfileBalancesSDK({
    query,
    ...getApiKeyMeta(),
    ...options,
  });
};
