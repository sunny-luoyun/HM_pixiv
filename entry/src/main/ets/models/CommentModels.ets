import { BookmarkData } from './CommonModels';

export interface AjaxCommentUser {
  id: string;
  name: string;
  account: string;
  img: string;
}

export interface AjaxComment {
  id: string;
  comment: string;
  date: string;
  userId: string;
  userName: string;
  userAccount: string;
  img: string;
  hasReplies: boolean;
  stamp?: object;
  replies?: AjaxComment[];
}

export interface AjaxCommentsBody {
  total: number;
  comments: AjaxComment[];
}

export interface AjaxCommentsResponse {
  error: boolean;
  message?: string;
  body: AjaxCommentsBody;
}
