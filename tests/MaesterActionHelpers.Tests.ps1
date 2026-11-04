BeforeAll {
    . (Join-Path -Path $PSScriptRoot -ChildPath '..' -AdditionalChildPath 'script', 'MaesterActionHelpers.ps1')

    $script:Gallery = @(
        '3.0.1-preview', '3.0.0', '3.0.0-preview',
        '2.2.100-preview', '2.2.99-preview', '2.2.10-preview', '2.2.0', '2.1.0', '2.0.0',
        '1.3.137-preview', '1.3.0'
    )
}

Describe 'Get-MaesterMajorVersion' {
    It 'defaults to 2 when empty' {
        Get-MaesterMajorVersion -MajorVersion '' | Should -Be 2
    }
    It 'accepts <_>' -ForEach '2', '3', ' 3 ' {
        Get-MaesterMajorVersion -MajorVersion $_ | Should -Be ([int]$_.Trim())
    }
    It 'rejects <_>' -ForEach '1', '4', 'latest', '3.0' {
        { Get-MaesterMajorVersion -MajorVersion $_ } | Should -Throw '*not supported*'
    }
}

Describe 'Resolve-MaesterVersion' {
    Context 'major version 2 (default)' {
        It 'latest resolves to the newest 2.x stable release, not 3.0' {
            (Resolve-MaesterVersion -MaesterVersion 'latest' -MajorVersion 2 -AvailableVersions $Gallery).Version | Should -Be '2.2.0'
        }
        It 'empty is treated as latest' {
            (Resolve-MaesterVersion -MaesterVersion '' -MajorVersion 2 -AvailableVersions $Gallery).Version | Should -Be '2.2.0'
        }
        It 'preview resolves to the newest 2.x prerelease, comparing versions numerically' {
            $result = Resolve-MaesterVersion -MaesterVersion 'preview' -MajorVersion 2 -AvailableVersions $Gallery
            $result.Version | Should -Be '2.2.100-preview'
            $result.IsPrerelease | Should -BeTrue
        }
        It 'an exact 2.x version wins' {
            (Resolve-MaesterVersion -MaesterVersion '2.1.0' -MajorVersion 2).Version | Should -Be '2.1.0'
        }
        It 'an exact 1.x version still works, for pipelines pinned to an older release' {
            (Resolve-MaesterVersion -MaesterVersion '1.3.0' -MajorVersion 2).Version | Should -Be '1.3.0'
            (Resolve-MaesterVersion -MaesterVersion '1.3.137-preview' -MajorVersion 2).Version | Should -Be '1.3.137-preview'
        }
        It 'an exact 3.x version fails and explains how to opt in' {
            { Resolve-MaesterVersion -MaesterVersion '3.0.0' -MajorVersion 2 } | Should -Throw "*maester_major_version: '3'*"
        }
    }

    Context 'major version 3 (opt-in)' {
        It 'latest resolves to the newest 3.x stable release' {
            (Resolve-MaesterVersion -MaesterVersion 'latest' -MajorVersion 3 -AvailableVersions $Gallery).Version | Should -Be '3.0.0'
        }
        It 'preview resolves to the newest 3.x release including prereleases' {
            (Resolve-MaesterVersion -MaesterVersion 'preview' -MajorVersion 3 -AvailableVersions $Gallery).Version | Should -Be '3.0.1-preview'
        }
        It 'a stable release wins over a prerelease of the same version' {
            (Resolve-MaesterVersion -MaesterVersion 'preview' -MajorVersion 3 -AvailableVersions '3.0.0-preview', '3.0.0').Version | Should -Be '3.0.0'
        }
        It 'preview finds a 3.0 prerelease before 3.0 is released' {
            (Resolve-MaesterVersion -MaesterVersion 'preview' -MajorVersion 3 -AvailableVersions '3.0.0-preview', '2.2.0').Version | Should -Be '3.0.0-preview'
        }
        It 'latest fails when no 3.x stable release exists yet' {
            { Resolve-MaesterVersion -MaesterVersion 'latest' -MajorVersion 3 -AvailableVersions '3.0.0-preview', '2.2.0' } | Should -Throw '*No Maester 3.x stable release*'
        }
        It 'an exact 1.x version fails' {
            { Resolve-MaesterVersion -MaesterVersion '1.3.0' -MajorVersion 3 } | Should -Throw "*maester_major_version is '3'*"
        }
        It 'an exact 2.x version fails' {
            { Resolve-MaesterVersion -MaesterVersion '2.2.0' -MajorVersion 3 } | Should -Throw "*maester_major_version is '3'*"
        }
    }

    It 'rejects a version that is not a number' {
        { Resolve-MaesterVersion -MaesterVersion 'newest' -MajorVersion 2 } | Should -Throw '*is not valid*'
    }
}

Describe 'Get-RemovedMaesterTag' {
    It 'finds All and Full regardless of case and spaces' {
        Get-RemovedMaesterTag -Tags 'CIS, all,Full,,EIDSCA' | Should -Be @('all', 'Full')
    }
    It 'returns nothing for other tags' {
        Get-RemovedMaesterTag -Tags 'CIS,Allowed,FullAccess' | Should -BeNullOrEmpty
    }
}

Describe 'Split-MaesterInputList' {
    It 'trims and drops empty entries' {
        Split-MaesterInputList -Value ' MT.1001, MT.1024.* ,,' | Should -Be @('MT.1001', 'MT.1024.*')
    }
    It 'returns nothing for an empty value' {
        Split-MaesterInputList -Value '' | Should -BeNullOrEmpty
    }
}

Describe 'Test-MaesterUsesTestPath' {
    It 'Maester 2 always uses the workspace path' {
        Test-MaesterUsesTestPath -MajorVersion 2 -IncludePrivateTests $false | Should -BeTrue
        Test-MaesterUsesTestPath -MajorVersion 2 -IncludePrivateTests $true | Should -BeTrue
    }
    It 'Maester 3 uses the workspace path when the repository is checked out' {
        Test-MaesterUsesTestPath -MajorVersion 3 -IncludePrivateTests $true | Should -BeTrue
    }
    It 'Maester 3 runs without a path when there is no checkout' {
        Test-MaesterUsesTestPath -MajorVersion 3 -IncludePrivateTests $false | Should -BeFalse
    }
}

Describe 'Test-MaesterSecurityComplianceInput' {
    It 'is valid when Security & Compliance is off' {
        Test-MaesterSecurityComplianceInput -IncludeSecurityCompliance $false -IncludeExchange $false | Should -BeTrue
        Test-MaesterSecurityComplianceInput -IncludeSecurityCompliance $false -IncludeExchange $true | Should -BeTrue
    }
    It 'is valid when Security & Compliance and Exchange Online are on' {
        Test-MaesterSecurityComplianceInput -IncludeSecurityCompliance $true -IncludeExchange $true | Should -BeTrue
    }
    It 'is invalid when Security & Compliance is on without Exchange Online' {
        Test-MaesterSecurityComplianceInput -IncludeSecurityCompliance $true -IncludeExchange $false | Should -BeFalse
    }
}

Describe 'Select-MaesterInitialDomain' {
    It 'returns the initial domain from Graph hashtables' {
        $domains = @(
            @{ id = 'contoso.com'; isInitial = $false }
            @{ id = 'contoso.onmicrosoft.com'; isInitial = $true }
        )
        Select-MaesterInitialDomain -Domain $domains | Should -Be 'contoso.onmicrosoft.com'
    }
    It 'returns the initial domain from objects' {
        $domains = @(
            [pscustomobject]@{ id = 'contoso.onmicrosoft.com'; isInitial = $true }
            [pscustomobject]@{ id = 'contoso.com'; isInitial = $false }
        )
        Select-MaesterInitialDomain -Domain $domains | Should -Be 'contoso.onmicrosoft.com'
    }
    It 'returns nothing when there is no initial domain' {
        Select-MaesterInitialDomain -Domain @(@{ id = 'contoso.com'; isInitial = $false }) | Should -BeNullOrEmpty
    }
    It 'returns nothing for an empty or missing list' {
        Select-MaesterInitialDomain -Domain @() | Should -BeNullOrEmpty
        Select-MaesterInitialDomain -Domain $null | Should -BeNullOrEmpty
    }
}

Describe 'ConvertTo-WorkflowCommandValue' {
    It 'escapes percent signs and line breaks' {
        ConvertTo-WorkflowCommandValue -Value "50%`r`nnext" | Should -Be '50%25%0D%0Anext'
    }
    It 'stops a message from starting a new workflow command' {
        $escaped = ConvertTo-WorkflowCommandValue -Value "failed`n::error::injected"
        $escaped | Should -Not -Match "`n"
        $escaped | Should -Be 'failed%0A::error::injected'
    }
    It 'leaves plain text unchanged' {
        ConvertTo-WorkflowCommandValue -Value 'Access denied' | Should -Be 'Access denied'
    }
    It 'accepts an empty string' {
        ConvertTo-WorkflowCommandValue -Value '' | Should -Be ''
    }
}
