USE [bodb_licensee]
GO
/****** Object:  StoredProcedure [dbo].[Lrf_UserInfoSelByUserName]    Script Date: 31/10/2014 13:17:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/****** Object:  Stored Procedure dbo.Lrf_UserInfoSel    Script Date: 10/5/2011 5:41:07 PM ******/
ALTER PROCEDURE [dbo].[Lrf_UserInfoSelByUserName] 
	 @UserName	NVARCHAR(50)
	, @LicenseeId	INT = 0,
	 @isInternal INT 
AS
/*
	Created by: [20141028@Florent.Nguyen ]
	Task: Get User Information Detail AND Page Access
	Base on : Lrf_UserInfoSel
	DB: DB052.bodb_Licensee
	Revisions:
		20170906@Harper: Get User with Status is Open [RedmineID: #82675]
		20171013@Alex  : Query user by system type [RedmineID: #84901]
		//@isInternal = 0 :IT Admin system
		//@isInternal =1  : Internal admin and LAP system
	
*/
SET NOCOUNT ON

SELECT DISTINCT  u.UserID
	  ,u.UserName
	  ,u.FirstName
	  ,u.LastName
	  ,u.UserPwd AS password
	  ,u.STATUS
	  ,u.isInternal AS IsInternal
	  ,u.UserSalt
FROM dbo.Users u(NOLOCK)
     INNER JOIN dbo.LicenseeUser l(NOLOCK) ON u.UserID = l.UserID and u.isInternal=@isInternal
WHERE u.Username = @UserName
	AND (
		@LicenseeId = 0
		OR (
			@LicenseeId <> 0
			AND l.LicenseeID = @LicenseeId
			)
		)

		

GO

GO
GRANT EXECUTE ON [dbo].[Lrf_UserInfoSelByUserName] TO [bodbLicenseeNet] 
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_UserInfoSelByUserName] TO [vnteam] 
