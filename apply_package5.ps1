$ErrorActionPreference = 'Stop'
$root = 'C:\shabashka_app'
$backupRoot = 'C:\shabashka_backups'
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$backupDir = Join-Path $backupRoot "package5_$stamp"
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Decode-Text([string]$value) {
    return [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($value))
}

$files = @(
    @{
        Relative = 'lib\providers\job_provider.dart'
        Before = '56a57fef719526edee04e25262553c913538086081cd1515365b648abe94807b'
        After = 'ee0e2839ba905b4c7d2b33d6143c6b15468576b241639a4f4b41543cb3ff62e8'
        Patches = @(
            @{ Old = 'ICAgIHRyeSB7CiAgICAgIGF3YWl0IFN1cGFiYXNlLmluc3RhbmNlLmNsaWVudC5hdXRoLnNpZ25PdXQoKTsKICAgIH0gY2F0Y2ggKF8pIHt9CiAgICB0cnkgewo='; New = 'ICAgIGF3YWl0IFB1c2hTZXJ2aWNlLmluc3RhbmNlLnVucmVnaXN0ZXIoKTsKICAgIGF3YWl0IFJlbWluZGVyU2VydmljZS5pbnN0YW5jZS5jbGVhckFsbCgpOwogICAgdHJ5IHsKICAgICAgYXdhaXQgU3VwYWJhc2UuaW5zdGFuY2UuY2xpZW50LmF1dGguc2lnbk91dCgpOwogICAgfSBjYXRjaCAoXykge30KICAgIHRyeSB7Cg==' },
            @{ Old = 'ICAgIHRyeSB7CiAgICAgIGZpbmFsIHByZWZzID0gYXdhaXQgU2hhcmVkUHJlZmVyZW5jZXMuZ2V0SW5zdGFuY2UoKTsKICAgICAgZmluYWwgZ3Vlc3RJZCA9ICdndWVzdF8ke0RhdGVUaW1lLm5vdygpLm1pY3Jvc2Vjb25kc1NpbmNlRXBvY2h9JzsK'; New = 'ICAgIGF3YWl0IFJlbWluZGVyU2VydmljZS5pbnN0YW5jZS5jbGVhckFsbCgpOwogICAgdHJ5IHsKICAgICAgZmluYWwgcHJlZnMgPSBhd2FpdCBTaGFyZWRQcmVmZXJlbmNlcy5nZXRJbnN0YW5jZSgpOwogICAgICBmaW5hbCBndWVzdElkID0gJ2d1ZXN0XyR7RGF0ZVRpbWUubm93KCkubWljcm9zZWNvbmRzU2luY2VFcG9jaH0nOwo=' }
        )
    },
    @{
        Relative = 'lib\services\push_service.dart'
        Before = '5bdddb450923fb45c239e9c8c45c6d44724ae4eb6cc029a949e11c02c4e76c91'
        After = '6dd13c61971d5a50166af20f8d9520880574d1d09ad053e9b1a7a4d96cd44b49'
        Patches = @(
            @{ Old = 'CiAgYm9vbCBnZXQgX3N1cHBvcnRlZCA9Pgo='; New = 'ICBTdHJpbmc/IF9sYXN0VG9rZW47CgogIGJvb2wgZ2V0IF9zdXBwb3J0ZWQgPT4K' },
            @{ Old = 'ICAgICAgICAgIF9zYXZlVG9rZW4odG9rZW4pOwo='; New = 'ICAgICAgICAgIF9sYXN0VG9rZW4gPSB0b2tlbjsKICAgICAgICAgIF9zYXZlVG9rZW4odG9rZW4pOwo=' },
            @{ Old = 'ICAgICAgICBhd2FpdCBfc2F2ZVRva2VuKHRva2VuKTsK'; New = 'ICAgICAgICBfbGFzdFRva2VuID0gdG9rZW47CiAgICAgICAgYXdhaXQgX3NhdmVUb2tlbih0b2tlbik7Cg==' },
            @{ Old = 'ICAgIH0KICB9CgogIC8vLyDQodC+0YXRgNCw0L3QuNGC0Ywv0L7QsdC90L7QstC40YLRjCDRgtC+0LrQtdC9INGC0LXQutGD0YnQtdCz0L4g0L/QvtC70YzQt9C+0LLQsNGC0LXQu9GPINCyINCx0LDQt9C1Lgo='; New = 'ICAgIH0KICB9CgogIC8vLyDQntGC0LLRj9C30LDRgtGMINGC0L7QutC10L0g0Y3RgtC+0LPQviDRg9GB0YLRgNC+0LnRgdGC0LLQsCDQtNC+INCy0YvRhdC+0LTQsCDQuNC3INGC0LXQutGD0YnQtdCz0L4g0LDQutC60LDRg9C90YLQsC4KICBGdXR1cmU8dm9pZD4gdW5yZWdpc3RlcigpIGFzeW5jIHsKICAgIGlmICghX3N1cHBvcnRlZCkgcmV0dXJuOwogICAgdHJ5IHsKICAgICAgZmluYWwgdXNlcklkID0gU3VwYWJhc2UuaW5zdGFuY2UuY2xpZW50LmF1dGguY3VycmVudFVzZXI/LmlkOwogICAgICBpZiAodXNlcklkID09IG51bGwpIHJldHVybjsKICAgICAgdmFyIHRva2VuID0gX2xhc3RUb2tlbiA/PyAnJzsKICAgICAgaWYgKHRva2VuLmlzRW1wdHkpIHsKICAgICAgICBmaW5hbCBhdmFpbGFibGUgPSBhd2FpdCBSdXN0b3JlUHVzaENsaWVudC5hdmFpbGFibGUoKTsKICAgICAgICBpZiAoYXZhaWxhYmxlID09IHRydWUpIHRva2VuID0gYXdhaXQgUnVzdG9yZVB1c2hDbGllbnQuZ2V0VG9rZW4oKTsKICAgICAgfQogICAgICBpZiAodG9rZW4uaXNFbXB0eSkgcmV0dXJuOwogICAgICBhd2FpdCBTdXBhYmFzZS5pbnN0YW5jZS5jbGllbnQKICAgICAgICAgIC5mcm9tKCdwdXNoX3Rva2VucycpCiAgICAgICAgICAuZGVsZXRlKCkKICAgICAgICAgIC5lcSgndXNlcl9pZCcsIHVzZXJJZCkKICAgICAgICAgIC5lcSgndG9rZW4nLCB0b2tlbik7CiAgICAgIF9sYXN0VG9rZW4gPSBudWxsOwogICAgfSBjYXRjaCAoZSkgewogICAgICBkZWJ1Z1ByaW50KCdwdXNoX3Rva2VucyB1bnJlZ2lzdGVyIGZhaWxlZDogJGUnKTsKICAgIH0KICB9CgogIC8vLyDQodC+0YXRgNCw0L3QuNGC0Ywv0L7QsdC90L7QstC40YLRjCDRgtC+0LrQtdC9INGC0LXQutGD0YnQtdCz0L4g0L/QvtC70YzQt9C+0LLQsNGC0LXQu9GPINCyINCx0LDQt9C1Lgo=' },
            @{ Old = 'ICAgICAgYXdhaXQgU3VwYWJhc2UuaW5zdGFuY2UuY2xpZW50LmZyb20oJ3B1c2hfdG9rZW5zJykudXBzZXJ0KAo='; New = 'ICAgICAgX2xhc3RUb2tlbiA9IHRva2VuOwogICAgICBhd2FpdCBTdXBhYmFzZS5pbnN0YW5jZS5jbGllbnQuZnJvbSgncHVzaF90b2tlbnMnKS51cHNlcnQoCg==' }
        )
    },
    @{
        Relative = 'lib\services\reminder_service.dart'
        Before = '1b181dff41f264acb1483e23643327623f897479a2b8447d87bd9bffbb7aad0f'
        After = '5117faa3622a60f59b19ca03f8a80ba06f4811af69d06b6240737a13dd0a2650'
        Patches = @(
            @{ Old = 'aW1wb3J0ICdwYWNrYWdlOmZsdXR0ZXIvZm91bmRhdGlvbi5kYXJ0JzsK'; New = 'aW1wb3J0ICdkYXJ0OmNvbnZlcnQnOwoKaW1wb3J0ICdwYWNrYWdlOmZsdXR0ZXIvZm91bmRhdGlvbi5kYXJ0JzsK' },
            @{ Old = 'aW1wb3J0ICdwYWNrYWdlOnRpbWV6b25lL2RhdGEvbGF0ZXN0LmRhcnQnIGFzIHR6ZGF0YTsK'; New = 'aW1wb3J0ICdwYWNrYWdlOnNoYXJlZF9wcmVmZXJlbmNlcy9zaGFyZWRfcHJlZmVyZW5jZXMuZGFydCc7CmltcG9ydCAncGFja2FnZTp0aW1lem9uZS9kYXRhL2xhdGVzdC5kYXJ0JyBhcyB0emRhdGE7Cg==' },
            @{ Old = 'ICAvLy8gam9iSWQgLT4gbm90aWZpY2F0aW9uSWQg0YPQttC1INC30LDQv9C70LDQvdC40YDQvtCy0LDQvdC90YvRhSDQvdCw0L/QvtC80LjQvdCw0L3QuNC5Lgo='; New = 'ICAvLy8gam9iSWQgLT4gbm90aWZpY2F0aW9uSWQgYWxyZWFkeSBzY2hlZHVsZWQgb24gdGhpcyBkZXZpY2UuCg==' },
            @{ Old = 'CiAgLy8vINCY0L3QuNGG0LjQsNC70LjQt9Cw0YbQuNGPINC/0LvQsNCz0LjQvdCwINC4INCx0LDQt9GLINGH0LDRgdC+0LLRi9GFINC/0L7Rj9GB0L7Qsi4g0JLRi9C30YvQstCw0LXRgtGB0Y8g0L7QtNC40L0g0YDQsNC3INCyIG1haW4oKS4K'; New = 'ICBzdGF0aWMgY29uc3QgU3RyaW5nIF9zY2hlZHVsZWRLZXkgPSAnam9iX3JlbWluZGVyc192Mic7CiAgc3RhdGljIGNvbnN0IFN0cmluZyBfbWlncmF0aW9uS2V5ID0gJ2pvYl9yZW1pbmRlcnNfdjJfbWlncmF0ZWQnOwoKICAvLy8g0JjQvdC40YbQuNCw0LvQuNC30LDRhtC40Y8g0L/Qu9Cw0LPQuNC90LAg0Lgg0LHQsNC30Ysg0YfQsNGB0L7QstGL0YUg0L/QvtGP0YHQvtCyLiDQktGL0LfRi9Cy0LDQtdGC0YHRjyDQvtC00LjQvSDRgNCw0Lcg0LIgbWFpbigpLgo=' },
            @{ Old = 'ICAgICAgY29uc3QgYW5kcm9pZCA9IEFuZHJvaWRJbml0aWFsaXphdGlvblNldHRpbmdzKCdAbWlwbWFwL2ljX2xhdW5jaGVyJyk7Cg=='; New = 'ICAgICAgX3NldExvY2FsVGltZXpvbmVGcm9tRGV2aWNlT2Zmc2V0KCk7CiAgICAgIGNvbnN0IGFuZHJvaWQgPSBBbmRyb2lkSW5pdGlhbGl6YXRpb25TZXR0aW5ncygnQG1pcG1hcC9pY19sYXVuY2hlcicpOwo=' },
            @{ Old = 'ICAgICAgX3JlYWR5ID0gdHJ1ZTsK'; New = 'ICAgICAgYXdhaXQgX3Jlc3RvcmVTY2hlZHVsZWQoKTsKICAgICAgX3JlYWR5ID0gdHJ1ZTsK' },
            @{ Old = 'ICBpbnQgX2lkRm9yKFN0cmluZyBqb2JJZCkgPT4gam9iSWQuaGFzaENvZGUgJiAweDdmZmZmZmZmOwo='; New = 'ICB2b2lkIF9zZXRMb2NhbFRpbWV6b25lRnJvbURldmljZU9mZnNldCgpIHsKICAgIC8vIFJ1c3NpYSBubyBsb25nZXIgdXNlcyBEU1QuIE1hcCB0aGUgZGV2aWNlIFVUQyBvZmZzZXQgdG8gYSBjYW5vbmljYWwKICAgIC8vIFJ1c3NpYW4gdGltZXpvbmUgc28gc2NoZWR1bGVkIGxvY2FsIHdhbGwtY2xvY2sgdGltZXMgc3RheSBjb3JyZWN0LgogICAgY29uc3QgbG9jYXRpb25zID0gPGludCwgU3RyaW5nPnsKICAgICAgMTIwOiAnRXVyb3BlL0thbGluaW5ncmFkJywKICAgICAgMTgwOiAnRXVyb3BlL01vc2NvdycsCiAgICAgIDI0MDogJ0V1cm9wZS9TYW1hcmEnLAogICAgICAzMDA6ICdBc2lhL1lla2F0ZXJpbmJ1cmcnLAogICAgICAzNjA6ICdBc2lhL09tc2snLAogICAgICA0MjA6ICdBc2lhL0tyYXNub3lhcnNrJywKICAgICAgNDgwOiAnQXNpYS9Jcmt1dHNrJywKICAgICAgNTQwOiAnQXNpYS9ZYWt1dHNrJywKICAgICAgNjAwOiAnQXNpYS9WbGFkaXZvc3RvaycsCiAgICAgIDY2MDogJ0FzaWEvTWFnYWRhbicsCiAgICAgIDcyMDogJ0FzaWEvS2FtY2hhdGthJywKICAgIH07CiAgICBmaW5hbCBtaW51dGVzID0gRGF0ZVRpbWUubm93KCkudGltZVpvbmVPZmZzZXQuaW5NaW51dGVzOwogICAgZmluYWwgbmFtZSA9IGxvY2F0aW9uc1ttaW51dGVzXTsKICAgIGlmIChuYW1lID09IG51bGwpIHJldHVybjsKICAgIHRyeSB7CiAgICAgIHR6LnNldExvY2FsTG9jYXRpb24odHouZ2V0TG9jYXRpb24obmFtZSkpOwogICAgfSBjYXRjaCAoZSkgewogICAgICBkZWJ1Z1ByaW50KCdSZW1pbmRlclNlcnZpY2UgdGltZXpvbmUgZmFpbGVkOiAkZScpOwogICAgfQogIH0KCiAgRnV0dXJlPHZvaWQ+IF9yZXN0b3JlU2NoZWR1bGVkKCkgYXN5bmMgewogICAgZmluYWwgcHJlZnMgPSBhd2FpdCBTaGFyZWRQcmVmZXJlbmNlcy5nZXRJbnN0YW5jZSgpOwogICAgZmluYWwgbWlncmF0ZWQgPSBwcmVmcy5nZXRCb29sKF9taWdyYXRpb25LZXkpID8/IGZhbHNlOwogICAgaWYgKCFtaWdyYXRlZCkgewogICAgICAvLyBPbGQgdmVyc2lvbnMgdXNlZCB1bnN0YWJsZSBTdHJpbmcuaGFzaENvZGUgSURzLiBSZW1vdmUgdGhvc2Ugb25jZTsKICAgICAgLy8gY3VycmVudCBqb2JzIHdpbGwgYmUgc2NoZWR1bGVkIGFnYWluIGJ5IHRoZSBuZXh0IHN5bmMuCiAgICAgIGF3YWl0IF9wbHVnaW4uY2FuY2VsQWxsKCk7CiAgICAgIGF3YWl0IHByZWZzLnNldEJvb2woX21pZ3JhdGlvbktleSwgdHJ1ZSk7CiAgICAgIGF3YWl0IHByZWZzLnJlbW92ZShfc2NoZWR1bGVkS2V5KTsKICAgICAgX3NjaGVkdWxlZC5jbGVhcigpOwogICAgICByZXR1cm47CiAgICB9CiAgICBmaW5hbCByYXcgPSBwcmVmcy5nZXRTdHJpbmcoX3NjaGVkdWxlZEtleSk7CiAgICBpZiAocmF3ID09IG51bGwpIHJldHVybjsKICAgIHRyeSB7CiAgICAgIGZpbmFsIGRlY29kZWQgPSBqc29uRGVjb2RlKHJhdyk7CiAgICAgIGlmIChkZWNvZGVkIGlzIE1hcCkgewogICAgICAgIGZvciAoZmluYWwgZW50cnkgaW4gZGVjb2RlZC5lbnRyaWVzKSB7CiAgICAgICAgICBmaW5hbCB2YWx1ZSA9IGVudHJ5LnZhbHVlOwogICAgICAgICAgaWYgKHZhbHVlIGlzIG51bSkgX3NjaGVkdWxlZFsnJHtlbnRyeS5rZXl9J10gPSB2YWx1ZS50b0ludCgpOwogICAgICAgIH0KICAgICAgfQogICAgfSBjYXRjaCAoXykgewogICAgICBfc2NoZWR1bGVkLmNsZWFyKCk7CiAgICAgIGF3YWl0IHByZWZzLnJlbW92ZShfc2NoZWR1bGVkS2V5KTsKICAgIH0KICB9CgogIEZ1dHVyZTx2b2lkPiBfcGVyc2lzdFNjaGVkdWxlZCgpIGFzeW5jIHsKICAgIHRyeSB7CiAgICAgIGZpbmFsIHByZWZzID0gYXdhaXQgU2hhcmVkUHJlZmVyZW5jZXMuZ2V0SW5zdGFuY2UoKTsKICAgICAgYXdhaXQgcHJlZnMuc2V0U3RyaW5nKF9zY2hlZHVsZWRLZXksIGpzb25FbmNvZGUoX3NjaGVkdWxlZCkpOwogICAgfSBjYXRjaCAoZSkgewogICAgICBkZWJ1Z1ByaW50KCdSZW1pbmRlclNlcnZpY2UgcGVyc2lzdGVuY2UgZmFpbGVkOiAkZScpOwogICAgfQogIH0KCiAgaW50IF9pZEZvcihTdHJpbmcgam9iSWQpIHsKICAgIC8vIERldGVybWluaXN0aWMgMzEtYml0IEZOVi0xYTsgdW5saWtlIFN0cmluZy5oYXNoQ29kZSB0aGlzIGlzIHN0YWJsZQogICAgLy8gYmV0d2VlbiBhcHBsaWNhdGlvbiBsYXVuY2hlcy4KICAgIHZhciBoYXNoID0gMHg4MTFjOWRjNTsKICAgIGZvciAoZmluYWwgdW5pdCBpbiBqb2JJZC5jb2RlVW5pdHMpIHsKICAgICAgaGFzaCBePSB1bml0OwogICAgICBoYXNoID0gKGhhc2ggKiAweDAxMDAwMTkzKSAmIDB4N2ZmZmZmZmY7CiAgICB9CiAgICByZXR1cm4gaGFzaDsKICB9Cg==' },
            @{ Old = 'ICAgICAgKTsKICAgICAgX3NjaGVkdWxlZFtqb2IuaWRdID0gaWQ7Cg=='; New = 'ICAgICAgICBwYXlsb2FkOiAnam9iOiR7am9iLmlkfScsCiAgICAgICk7CiAgICAgIF9zY2hlZHVsZWRbam9iLmlkXSA9IGlkOwo=' },
            @{ Old = 'ICAgIH0gY2F0Y2ggKGUpIHsKICAgICAgZGVidWdQcmludCgnUmVtaW5kZXJTZXJ2aWNlIHNjaGVkdWxlIGZhaWxlZDogJGUnKTsK'; New = 'ICAgICAgYXdhaXQgX3BlcnNpc3RTY2hlZHVsZWQoKTsKICAgIH0gY2F0Y2ggKGUpIHsKICAgICAgZGVidWdQcmludCgnUmVtaW5kZXJTZXJ2aWNlIHNjaGVkdWxlIGZhaWxlZDogJGUnKTsK' },
            @{ Old = 'ICB9CgogIC8vLyDQr9Cy0L3QsNGPINC+0YLQvNC10L3QsCDQvdCw0L/QvtC80LjQvdCw0L3QuNGPINC/0L4g0L7QtNC90L7QuSDQt9Cw0Y/QstC60LUuCg=='; New = 'ICAgIGF3YWl0IF9wZXJzaXN0U2NoZWR1bGVkKCk7CiAgfQoKICAvLy8gQ2FuY2VsIGV2ZXJ5IHJlbWluZGVyIHdoZW4gdGhlIGFjdGl2ZSBhY2NvdW50IGNoYW5nZXMgb3IgaXMgZGVsZXRlZC4KICBGdXR1cmU8dm9pZD4gY2xlYXJBbGwoKSBhc3luYyB7CiAgICBpZiAoIV9yZWFkeSB8fCBrSXNXZWIpIHsKICAgICAgX3NjaGVkdWxlZC5jbGVhcigpOwogICAgICByZXR1cm47CiAgICB9CiAgICB0cnkgewogICAgICBhd2FpdCBfcGx1Z2luLmNhbmNlbEFsbCgpOwogICAgfSBjYXRjaCAoZSkgewogICAgICBkZWJ1Z1ByaW50KCdSZW1pbmRlclNlcnZpY2UgY2FuY2VsQWxsIGZhaWxlZDogJGUnKTsKICAgIH0KICAgIF9zY2hlZHVsZWQuY2xlYXIoKTsKICAgIGF3YWl0IF9wZXJzaXN0U2NoZWR1bGVkKCk7CiAgfQoKICAvLy8g0K/QstC90LDRjyDQvtGC0LzQtdC90LAg0L3QsNC/0L7QvNC40L3QsNC90LjRjyDQv9C+INC+0LTQvdC+0Lkg0LfQsNGP0LLQutC1Lgo=' }
        )
    }
)

New-Item -ItemType Directory -Force -Path $backupDir | Out-Null

foreach ($file in $files) {
    $target = Join-Path $root $file.Relative
    if (-not (Test-Path $target)) { throw "File not found: $target" }
    $actual = (Get-FileHash $target -Algorithm SHA256).Hash.ToLower()
    if ($actual -ne $file.Before) {
        throw "Source SHA256 mismatch for $($file.Relative). Expected $($file.Before), found $actual. Nothing changed."
    }
    $backup = Join-Path $backupDir $file.Relative
    New-Item -ItemType Directory -Force -Path (Split-Path $backup -Parent) | Out-Null
    Copy-Item $target $backup -Force
}

Write-Host "Backup: $backupDir"

try {
    foreach ($file in $files) {
        $target = Join-Path $root $file.Relative
        $content = [IO.File]::ReadAllText($target, [Text.Encoding]::UTF8)
        $content = $content.Replace("`r`n", "`n")
        foreach ($patch in $file.Patches) {
            $old = Decode-Text $patch.Old
            $new = Decode-Text $patch.New
            $count = ([regex]::Matches($content, [regex]::Escape($old))).Count
            if ($count -ne 1) { throw "Patch match count $count for $($file.Relative)" }
            $content = $content.Replace($old, $new)
        }
        if ($content.Contains([char]0xFFFD)) { throw "Damaged Unicode in $($file.Relative)" }
        [IO.File]::WriteAllText($target, $content, $utf8NoBom)
        $actual = (Get-FileHash $target -Algorithm SHA256).Hash.ToLower()
        if ($actual -ne $file.After) { throw "Final SHA256 mismatch for $($file.Relative): $actual" }
    }
}
catch {
    foreach ($file in $files) {
        $target = Join-Path $root $file.Relative
        $backup = Join-Path $backupDir $file.Relative
        if (Test-Path $backup) { Copy-Item $backup $target -Force }
    }
    throw "Package 5 failed. All originals restored. $($_.Exception.Message)"
}

Write-Host 'PACKAGE5_PUSH_REMINDERS_APPLIED_OK'
Write-Host 'Next: flutter analyze'
