# 랭킹 중계 서버

skills.sh v1 API(`https://skills.sh/api/v1/skills`)는 Vercel OIDC 토큰을 요구한다.
앱이 직접 부를 수 없으므로 이 Vercel 함수가 토큰을 붙여 대신 호출하고, 응답을 그대로 돌려준다.

## 엔드포인트

`GET /api/ranking?view=all-time|trending|hot&page=&per_page=`

| 파라미터 | 규칙 |
|---|---|
| `view` | `all-time`, `trending`, `hot` 중 하나. 아니면 400 |
| `page` | 1 이상 정수. 아니면 400 |
| `per_page` | 1~500 정수. 아니면 400 |

- 값이 없는 파라미터는 업스트림에 보내지 않는다.
- 업스트림이 200이면 본문을 그대로 전달하고 `Cache-Control: s-maxage=300`을 붙인다.
- 429·503은 상태 코드 그대로 전달한다 (`Retry-After`가 있으면 함께).
- 그 외 실패는 502 `{"error": "..."}`.
- 토큰은 요청 핸들러 안에서 `getVercelOidcToken()`으로만 얻고, 응답과 로그에 넣지 않는다.

응답 모양:

```json
{
  "data": [
    { "id": "", "slug": "", "name": "", "source": "", "installs": 0,
      "sourceType": "", "installUrl": "", "url": "",
      "installsYesterday": 0, "change": 0 }
  ],
  "pagination": { "page": 1, "perPage": 0, "total": 0, "hasMore": false }
}
```

`installsYesterday`, `change`는 없을 수 있다. 위 값은 모양만 보인 자리표시이며 실제 데이터가 아니다.

## 배포 순서

배포는 사람이 직접 한다. 아래 순서를 지킨다.

1. `vercel link` — `relay/` 폴더에서 실행해 Vercel 프로젝트와 연결한다.
2. OIDC Federation 켜기 — Vercel 대시보드의 프로젝트 Settings → Security에서 OIDC Federation(Secure backend access with OIDC tokens)을 켠다. 메뉴 이름은 Vercel 쪽 변경에 따라 다를 수 있다.
3. `vercel deploy` — 배포한다. 운영 반영은 `vercel deploy --prod`.

배포 후 나온 주소를 앱 실행 때 `--dart-define=RANKING_API_BASE=<주소>`로 넘긴다.

## 로컬 실행

```
cd relay
npm install
npx tsc --noEmit        # 타입 검사
vercel env pull         # OIDC 토큰을 .env.local 로 받는다 (link 이후)
vercel dev              # 로컬 서버
```

- `vercel env pull`로 받은 토큰은 만료되므로 필요할 때 다시 받는다.
- `.env*`와 `.vercel`은 `.gitignore`에 들어 있어 커밋되지 않는다. 절대 커밋하지 않는다.
