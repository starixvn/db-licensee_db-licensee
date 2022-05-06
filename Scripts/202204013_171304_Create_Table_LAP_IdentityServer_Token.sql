/*<info serverAlias="DBCUST-bodb_Licensee"></info>*/
/*
	Created: 20220413@Howard
	DB: DBCUST-bodb_Licensee
	Task: LAP - Store tokens on SQL Server
	RedmineID: #171304 - LAP - Enhancement
*/

USE bodb_Licensee

GO

CREATE TABLE [dbo].[LAP_IdentityServer_Token](
	[Key] [nvarchar](200) NOT NULL,
	[Type] [nvarchar](50) NOT NULL,
	[SubjectId] [nvarchar](200) NULL,
	[SessionId] [nvarchar](100) NULL,
	[ClientId] [nvarchar](200) NOT NULL,
	[Description] [nvarchar](200) NULL,
	[CreationTime] [datetime] NOT NULL,
	[Expiration] [datetime] NULL,
	[ConsumedTime] [datetime] NULL,
	[Data] [nvarchar](max) NOT NULL,
 CONSTRAINT [PK_LAP_IdentityServer_Token] PRIMARY KEY CLUSTERED 
(
	[Key] ASC
) ON [licensee_table]
) ON [licensee_table]

GO

CREATE NONCLUSTERED INDEX [IX_Expiration] ON [LAP_IdentityServer_Token] ([Expiration]) ON [licensee_index];

GO

CREATE NONCLUSTERED INDEX [IX_SubjectId_ClientId_Type] ON [LAP_IdentityServer_Token] ([SubjectId], [ClientId], [Type]) ON [licensee_index]

GO

CREATE NONCLUSTERED INDEX [IX_SubjectId_SessionId_Type] ON [LAP_IdentityServer_Token] ([SubjectId], [SessionId], [Type]) ON [licensee_index]

GO