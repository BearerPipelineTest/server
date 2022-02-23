-- Create Organization ApiKey table
IF OBJECT_ID('[dbo].[OrganizationApiKey]') IS NULL
BEGIN
CREATE TABLE [dbo].[OrganizationApiKey] (
    [OrganizationId]    UNIQUEIDENTIFIER NOT NULL,
    [Type]              TINYINT NOT NULL,
    [ApiKey]            VARCHAR(30) NOT NULL,
    [RevisionDate]      DATETIME2(7) NOT NULL
    CONSTRAINT [PK_OrganizationApiKey] PRIMARY KEY CLUSTERED ([OrganizationId] ASC, [Type] ASC),
    CONSTRAINT [FK_OrganizationApiKey_OrganizationId] FOREIGN KEY ([OrganizationId]) REFERENCES [dbo].[Organization] ([Id])
);
END
GO

-- Create indexes
IF NOT EXISTS(SELECT name FROM sys.indexes WHERE name = 'IX_OrganizationApiKey_OrganizationId')
BEGIN
CREATE NONCLUSTERED INDEX [IX_OrganizationApiKey_OrganizationId]
    ON [dbo].[OrganizationApiKey]([OrganizationId] ASC);
END
GO

IF NOT EXISTS(SELECT name FROM sys.indexes WHERE name = 'IX_OrganizationApiKey_ApiKey')
BEGIN
CREATE NONCLUSTERED INDEX [IX_OrganizationApiKey_ApiKey]
    ON [dbo].[OrganizationApiKey]([ApiKey] ASC);
END
GO

IF EXISTS(SELECT * FROM sys.views WHERE [Name] = 'OrganizationApiKeyView')
BEGIN
    DROP VIEW [dbo].[OrganizationApiKeyView];
END
GO

CREATE VIEW [dbo].[OrganizationApiKeyView]
AS
SELECT
    *
FROM
    [dbo].[OrganizationApiKey]
GO

IF OBJECT_ID('[dbo].[OrganizationApiKey_Create]') IS NOT NULL
BEGIN
    DROP PROCEDURE [dbo].[OrganizationApiKey_Create]
END
GO

CREATE PROCEDURE [dbo].[OrganizationApiKey_Create]
    @OrganizationId UNIQUEIDENTIFIER,
    @ApiKey VARCHAR(30),
    @Type TINYINT,
    @RevisionDate DATETIME2(7)
AS
BEGIN
    SET NOCOUNT ON

    INSERT INTO [dbo].[OrganizationApiKey]
    (
        [OrganizationId],
        [ApiKey],
        [Type],
        [RevisionDate]
    )
    VALUES
    (
        @OrganizationId,
        @ApiKey,
        @Type,
        @RevisionDate
    )
END
GO

IF OBJECT_ID('[dbo].[OrganizationApiKey_Update]') IS NOT NULL
BEGIN
    DROP PROCEDURE [dbo].[OrganizationApiKey_Update]
END
GO

CREATE PROCEDURE [dbo].[OrganizationApiKey_Update]
    @OrganizationId UNIQUEIDENTIFIER,
    @Type TINYINT,
    @ApiKey VARCHAR(30),
    @RevisionDate DATETIME2(7)
AS
BEGIN
    SET NOCOUNT ON

    UPDATE
        [dbo].[OrganizationApiKey]
    SET
        [ApiKey] = @ApiKey,
        [RevisionDate] = @RevisionDate
    WHERE
        [OrganizationId] = @OrganizationId AND
        [Type] = @Type
END
GO

IF OBJECT_ID('[dbo].[OrganizationApiKey_ReadByOrganizationId]') IS NOT NULL
BEGIN
    DROP PROCEDURE [dbo].[OrganizationApiKey_ReadByOrganizationId]
END
GO

CREATE PROCEDURE [dbo].[OrganizationApiKey_ReadByOrganizationId]
    @OrganizationId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON

    SELECT
        *
    FROM
        [dbo].[OrganizationApiKeyView]
    WHERE
        [OrganizationId] = @OrganizationId
END
GO

IF OBJECT_ID('[dbo].[OrganizationApiKey_ReadCanUseByOrganizationIdApiKey]') IS NOT NULL
BEGIN
    DROP PROCEDURE [dbo].[OrganizationApiKey_ReadCanUseByOrganizationIdApiKey]
END
GO

CREATE PROCEDURE [dbo].[OrganizationApiKey_ReadCanUseByOrganizationIdApiKey]
    @OrganizationId UNIQUEIDENTIFIER,
    @ApiKey VARCHAR(30),
    @Type TINYINT
AS
BEGIN
    SET NOCOUNT ON

    DECLARE @CanUse BIT

    SELECT
        @CanUse = CASE
            WHEN COUNT(1) > 0 THEN 1
            ELSE 0
        END
    FROM
        [dbo].[OrganizationApiKeyView]
    WHERE
        [OrganizationId] = @OrganizationId AND
        [ApiKey] = @ApiKey AND
        [Type] = @Type
END
GO

IF OBJECT_ID('[dbo].[OrganizationApiKey_ReadByOrganizationIdType]') IS NOT NULL
BEGIN
    DROP PROCEDURE [dbo].[OrganizationApiKey_ReadByOrganizationIdType]
END
GO

CREATE PROCEDURE [dbo].[OrganizationApiKey_ReadByOrganizationIdType]
    @OrganizationId UNIQUEIDENTIFIER,
    @Type TINYINT
AS
BEGIN
    SET NOCOUNT ON

    SELECT
        *
    FROM
        [dbo].[OrganizationApiKeyView]
    WHERE
        [OrganizationId] = @OrganizationId AND
        [Type] = @Type
END
GO

IF OBJECT_ID('[dbo].[OrganizationApiKey_OrganizationDeleted]') IS NOT NULL
BEGIN
    DROP PROCEDURE [dbo].[OrganizationApiKey_OrganizationDeleted]
END
GO

CREATE PROCEDURE [dbo].[OrganizationApiKey_OrganizationDeleted]
    @OrganizationId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON

    DELETE
    FROM
        [dbo].[OrganizationApiKey]
    WHERE
        [OrganizationId] = @OrganizationId
END
GO

-- Update Organization delete sprocs to handle organization api key
IF OBJECT_ID('[dbo].[Organization_DeleteById]') IS NOT NULL
BEGIN
    DROP PROCEDURE [dbo].[Organization_DeleteById]
END
GO

CREATE PROCEDURE [dbo].[Organization_DeleteById]
    @Id UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON

    EXEC [dbo].[User_BumpAccountRevisionDateByOrganizationId] @Id

    DECLARE @BatchSize INT = 100
    WHILE @BatchSize > 0
    BEGIN
        BEGIN TRANSACTION Organization_DeleteById_Ciphers

        DELETE TOP(@BatchSize)
        FROM
            [dbo].[Cipher]
        WHERE
            [UserId] IS NULL
            AND [OrganizationId] = @Id

        SET @BatchSize = @@ROWCOUNT

        COMMIT TRANSACTION Organization_DeleteById_Ciphers
    END

    BEGIN TRANSACTION Organization_DeleteById

    DELETE
    FROM
        [dbo].[SsoUser]
    WHERE
        [OrganizationId] = @Id

    DELETE
    FROM
        [dbo].[SsoConfig]
    WHERE
        [OrganizationId] = @Id

    DELETE CU
    FROM 
        [dbo].[CollectionUser] CU
    INNER JOIN 
        [dbo].[OrganizationUser] OU ON [CU].[OrganizationUserId] = [OU].[Id]
    WHERE 
        [OU].[OrganizationId] = @Id

    DELETE
    FROM 
        [dbo].[OrganizationUser]
    WHERE 
        [OrganizationId] = @Id

    DELETE
    FROM
         [dbo].[ProviderOrganization]
    WHERE
        [OrganizationId] = @Id

    EXEC [dbo].[OrganizationSponsorship_OrganizationDeleted] @Id
    EXEC [dbo].[OrganizationApiKey_OrganizationDeleted] @Id

    DELETE
    FROM
        [dbo].[Organization]
    WHERE
        [Id] = @Id

    COMMIT TRANSACTION Organization_DeleteById
END
GO


IF COL_LENGTH('[dbo].[Organization]', 'ApiKey') IS NOT NULl
BEGIN
    BEGIN TRANSACTION MigrateOrganizationApiKeys
    INSERT INTO [dbo].[OrganizationApiKey]
        (
            [OrganizationId], 
            [ApiKey], 
            [Type]
        )
        SELECT
            [Id] AS [OrganizationId], 
            [ApiKey] AS [ApiKey], 
            0 AS [Type] -- 0 represents 'Default' type
        FROM [dbo].[Organization]

    COMMIT TRANSACTION MigrateOrganizationApiKeys;
    
    BEGIN TRANSACTION DeleteOldApiKeys
    ALTER TABLE
        [dbo].[Organization]
    DROP COLUMN
        [ApiKey]
    COMMIT TRANSACTION DeleteOldApiKeys;
END
GO


IF OBJECT_ID('[dbo].[Organization_Create]') IS NOT NULL
BEGIN
    DROP PROCEDURE [dbo].[Organization_Create]
END
GO

CREATE PROCEDURE [dbo].[Organization_Create]
    @Id UNIQUEIDENTIFIER OUTPUT,
    @Identifier NVARCHAR(50),
    @Name NVARCHAR(50),
    @BusinessName NVARCHAR(50),
    @BusinessAddress1 NVARCHAR(50),
    @BusinessAddress2 NVARCHAR(50),
    @BusinessAddress3 NVARCHAR(50),
    @BusinessCountry VARCHAR(2),
    @BusinessTaxNumber NVARCHAR(30),
    @BillingEmail NVARCHAR(256),
    @Plan NVARCHAR(50),
    @PlanType TINYINT,
    @Seats INT,
    @MaxCollections SMALLINT,
    @UsePolicies BIT,
    @UseSso BIT,
    @UseGroups BIT,
    @UseDirectory BIT,
    @UseEvents BIT,
    @UseTotp BIT,
    @Use2fa BIT,
    @UseApi BIT,
    @UseResetPassword BIT,
    @SelfHost BIT,
    @UsersGetPremium BIT,
    @Storage BIGINT,
    @MaxStorageGb SMALLINT,
    @Gateway TINYINT,
    @GatewayCustomerId VARCHAR(50),
    @GatewaySubscriptionId VARCHAR(50),
    @ReferenceData VARCHAR(MAX),
    @Enabled BIT,
    @LicenseKey VARCHAR(100),
    @PublicKey VARCHAR(MAX),
    @PrivateKey VARCHAR(MAX),
    @TwoFactorProviders NVARCHAR(MAX),
    @ExpirationDate DATETIME2(7),
    @CreationDate DATETIME2(7),
    @RevisionDate DATETIME2(7),
    @OwnersNotifiedOfAutoscaling DATETIME2(7),
    @MaxAutoscaleSeats INT,
    @UseKeyConnector BIT = 0
AS
BEGIN
    SET NOCOUNT ON

    INSERT INTO [dbo].[Organization]
    (
        [Id],
        [Identifier],
        [Name],
        [BusinessName],
        [BusinessAddress1],
        [BusinessAddress2],
        [BusinessAddress3],
        [BusinessCountry],
        [BusinessTaxNumber],
        [BillingEmail],
        [Plan],
        [PlanType],
        [Seats],
        [MaxCollections],
        [UsePolicies],
        [UseSso],
        [UseGroups],
        [UseDirectory],
        [UseEvents],
        [UseTotp],
        [Use2fa],
        [UseApi],
        [UseResetPassword],
        [SelfHost],
        [UsersGetPremium],
        [Storage],
        [MaxStorageGb],
        [Gateway],
        [GatewayCustomerId],
        [GatewaySubscriptionId],
        [ReferenceData],
        [Enabled],
        [LicenseKey],
        [PublicKey],
        [PrivateKey],
        [TwoFactorProviders],
        [ExpirationDate],
        [CreationDate],
        [RevisionDate],
        [OwnersNotifiedOfAutoscaling],
        [MaxAutoscaleSeats],
        [UseKeyConnector]
    )
    VALUES
    (
        @Id,
        @Identifier,
        @Name,
        @BusinessName,
        @BusinessAddress1,
        @BusinessAddress2,
        @BusinessAddress3,
        @BusinessCountry,
        @BusinessTaxNumber,
        @BillingEmail,
        @Plan,
        @PlanType,
        @Seats,
        @MaxCollections,
        @UsePolicies,
        @UseSso,
        @UseGroups,
        @UseDirectory,
        @UseEvents,
        @UseTotp,
        @Use2fa,
        @UseApi,
        @UseResetPassword,
        @SelfHost,
        @UsersGetPremium,
        @Storage,
        @MaxStorageGb,
        @Gateway,
        @GatewayCustomerId,
        @GatewaySubscriptionId,
        @ReferenceData,
        @Enabled,
        @LicenseKey,
        @PublicKey,
        @PrivateKey,
        @TwoFactorProviders,
        @ExpirationDate,
        @CreationDate,
        @RevisionDate,
        @OwnersNotifiedOfAutoscaling,
        @MaxAutoscaleSeats,
        @UseKeyConnector
    )
END
GO

IF OBJECT_ID('[dbo].[Organization_Update]') IS NOT NULL
BEGIN
    DROP PROCEDURE [dbo].[Organization_Update]
END
GO

CREATE PROCEDURE [dbo].[Organization_Update]
    @Id UNIQUEIDENTIFIER,
    @Identifier NVARCHAR(50),
    @Name NVARCHAR(50),
    @BusinessName NVARCHAR(50),
    @BusinessAddress1 NVARCHAR(50),
    @BusinessAddress2 NVARCHAR(50),
    @BusinessAddress3 NVARCHAR(50),
    @BusinessCountry VARCHAR(2),
    @BusinessTaxNumber NVARCHAR(30),
    @BillingEmail NVARCHAR(256),
    @Plan NVARCHAR(50),
    @PlanType TINYINT,
    @Seats INT,
    @MaxCollections SMALLINT,
    @UsePolicies BIT,
    @UseSso BIT,
    @UseGroups BIT,
    @UseDirectory BIT,
    @UseEvents BIT,
    @UseTotp BIT,
    @Use2fa BIT,
    @UseApi BIT,
    @UseResetPassword BIT,
    @SelfHost BIT,
    @UsersGetPremium BIT,
    @Storage BIGINT,
    @MaxStorageGb SMALLINT,
    @Gateway TINYINT,
    @GatewayCustomerId VARCHAR(50),
    @GatewaySubscriptionId VARCHAR(50),
    @ReferenceData VARCHAR(MAX),
    @Enabled BIT,
    @LicenseKey VARCHAR(100),
    @PublicKey VARCHAR(MAX),
    @PrivateKey VARCHAR(MAX),
    @TwoFactorProviders NVARCHAR(MAX),
    @ExpirationDate DATETIME2(7),
    @CreationDate DATETIME2(7),
    @RevisionDate DATETIME2(7),
    @OwnersNotifiedOfAutoscaling DATETIME2(7),
    @MaxAutoscaleSeats INT,
    @UseKeyConnector BIT = 0
AS
BEGIN
    SET NOCOUNT ON

    UPDATE
        [dbo].[Organization]
    SET
        [Identifier] = @Identifier,
        [Name] = @Name,
        [BusinessName] = @BusinessName,
        [BusinessAddress1] = @BusinessAddress1,
        [BusinessAddress2] = @BusinessAddress2,
        [BusinessAddress3] = @BusinessAddress3,
        [BusinessCountry] = @BusinessCountry,
        [BusinessTaxNumber] = @BusinessTaxNumber,
        [BillingEmail] = @BillingEmail,
        [Plan] = @Plan,
        [PlanType] = @PlanType,
        [Seats] = @Seats,
        [MaxCollections] = @MaxCollections,
        [UsePolicies] = @UsePolicies,
        [UseSso] = @UseSso,
        [UseGroups] = @UseGroups,
        [UseDirectory] = @UseDirectory,
        [UseEvents] = @UseEvents,
        [UseTotp] = @UseTotp,
        [Use2fa] = @Use2fa,
        [UseApi] = @UseApi,
        [UseResetPassword] = @UseResetPassword,
        [SelfHost] = @SelfHost,
        [UsersGetPremium] = @UsersGetPremium,
        [Storage] = @Storage,
        [MaxStorageGb] = @MaxStorageGb,
        [Gateway] = @Gateway,
        [GatewayCustomerId] = @GatewayCustomerId,
        [GatewaySubscriptionId] = @GatewaySubscriptionId,
        [ReferenceData] = @ReferenceData,
        [Enabled] = @Enabled,
        [LicenseKey] = @LicenseKey,
        [PublicKey] = @PublicKey,
        [PrivateKey] = @PrivateKey,
        [TwoFactorProviders] = @TwoFactorProviders,
        [ExpirationDate] = @ExpirationDate,
        [CreationDate] = @CreationDate,
        [RevisionDate] = @RevisionDate,
        [OwnersNotifiedOfAutoscaling] = @OwnersNotifiedOfAutoscaling,
        [MaxAutoscaleSeats] = @MaxAutoscaleSeats,
        [UseKeyConnector] = @UseKeyConnector
    WHERE
        [Id] = @Id
END
GO

IF OBJECT_ID('[dbo].[OrganizationView]') IS NOT NULL
BEGIN
    DROP VIEW [dbo].[OrganizationView]
END
GO

CREATE VIEW [dbo].[OrganizationView]
AS
SELECT
    *
FROM
    [dbo].[Organization]
GO


IF OBJECT_ID('[dbo].[OrganizationSponsorship_ReadFirstBySponsoringOrganizationId]') IS NOT NULL
BEGIN
    DROP PROCEDURE [dbo].[OrganizationSponsorship_ReadFirstBySponsoringOrganizationId];
END
GO

CREATE PROCEDURE [dbo].[OrganizationSponsorship_ReadFirstBySponsoringOrganizationId]
    @SponsoringOrganizationId UNIQUEIDENTIFIER
AS
BEGIN
    SELECT TOP 1
        *
    FROM
        [dbo].[OrganizationSponsorship]
    WHERE
        [SponsoringOrganizationId] = @SponsoringOrganizationId
END
GO