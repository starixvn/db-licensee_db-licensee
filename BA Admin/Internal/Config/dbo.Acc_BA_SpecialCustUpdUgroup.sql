ALTER PROCEDURE [dbo].[Acc_BA_SpecialCustUpdUgroup]
	@custid int,
	@ugroup varchar(3),
	@userid int,
	@IP varchar(50) = '',
	@ErrCode int = 0 OUTPUT,
	@ErrMsg nvarchar(200) = '' OUTPUT
AS
 /*
Created:
Task : Update Customer User group when modify Special Cust
DB: DBTRANS.bodb02
Original:

Revisions:    
	
Param's Explanation:
*/

SET NOCOUNT ON

declare @startRun datetime
declare @endRun datetime
declare @duration int
set @startRun = getdate()

declare @old_ugroup varchar(3), @username NVARCHAR(50)

select
	@old_ugroup = ugroup,
	@username = @username
from customer with(nolock)
where
	custid = @custid
	and roleid = 1


if isnull(@custid, 0) = 0
BEGIN
	Select @ErrMsg = 'Invalid user. Member '+@username+' is not found.',
		@ErrCode = 101					 	
	return	
END


UPDATE customer WITH (ROWLOCK, UPDLOCK)
SET
	ugroup = @ugroup
WHERE custid=@custid

declare @LogSPData varchar(5000)

Select @LogSPData = '<Acc_BA_SpecialCustUpdUgroup Custid="'+ coalesce(cast(@custid as varchar(50)),space(1)) + '" From="' + @old_ugroup 
					+ '" To="' + @ugroup +'" '+
					'Userid="'+ coalesce(cast(@userid as varchar(50)),space(1)) + '" '+
					'IP="'+ coalesce(cast(@IP as varchar(15)),space(1)) + '" '+
					'ErrCode="'+ coalesce(cast(@ErrCode as varchar(50)),space(1)) + '" '+
					'ErrMsg="'+ coalesce(cast(@ErrMsg as varchar(400)),space(1))+'" />'

set @endRun = getdate()
set @duration  = datediff (millisecond,@startRun,@endRun)

/*608 Acc_CustomerUpdUserGroup Change user group */
EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_RunSP
	@UserID = @UserID,
	@CustID = @CustID,
	@ActionID = 2416,
	@TrackingValue = @LogSPData,
	@duration = @duration


GO
GRANT EXECUTE ON [dbo].[Acc_BA_SpecialCustUpdUgroup] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Acc_BA_SpecialCustUpdUgroup] TO [vnteam]
 