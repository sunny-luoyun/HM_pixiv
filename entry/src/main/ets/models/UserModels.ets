export interface UserInfoBody {
  userId?: string;
  name: string;
  image?: string;
  imageBig?: string;
}

export interface UserInfoResponse {
  error: boolean;
  body?: UserInfoBody;
}

export interface UserSearchResult {
  userId: string;
  name: string;
  image: string;
  imageBig: string;
  comment: string;
  premium: boolean;
  isFollowed: boolean;
  following: number;
}

export interface SearchUserPage {
  userIds: number[];
  total: number;
}

export interface SearchUserBody {
  users: UserSearchResult[];
  page: SearchUserPage;
}

export interface SearchUserResponse {
  error: boolean;
  body: SearchUserBody;
}

export interface FollowingUserRaw {
  userId: string;
  userName: string;
  profileImageUrl: string;
  userComment: string;
  following: boolean;
  followed: boolean;
  isBlocking: boolean;
  isMypixiv: boolean;
  acceptRequest: boolean;
}

export interface FollowingUserBody {
  total: number;
  users: FollowingUserRaw[];
}

export interface FollowingUserResponse {
  error: boolean;
  body: FollowingUserBody;
}

export interface ProfileAllBody {
  illusts: Record<string, null>;
  manga: Record<string, null>;
  novels: Record<string, null>;
}

export interface ProfileAllResponse {
  error: boolean;
  body: ProfileAllBody;
}
