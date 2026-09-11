# AI引継ぎ帳 v0.4 CI source parts

このディレクトリの `part_00.b64` から `part_22.b64` は、v0.4最小ソースアーカイブを1,024バイト単位でBase64化した検証用部品です。

CIは各部品を個別に復号して連結し、SHA-256 `cdb7067a29385d346edadb7506f39f7e5cfd567a07e930e5b43344ae4f50e234` と一致した場合のみFlutter検証へ進みます。

mainへはマージしません。