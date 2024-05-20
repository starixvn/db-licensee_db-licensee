/*<info serverAlias="DBWH-bodb_DWRS" executers="wsv_lap" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE Lrf_AbnormalBet_SubIssueSel
    @Langkey VARCHAR(20) = 'en-US'  
AS  
 /*  
  Created: 20221028@Evan  
  Task: AbnormalBet - Get Ticket Voiding Type (Reason)  
  DB: DBWH-bodb_DWRS  
    
  Revisions:  
   - 20221028@Evan: initial sp [redmine:#174308]  
  Paramter's Explanations: 
  Note: Get Reason for Dropdown list  
 */  
BEGIN  
    SET NOCOUNT ON  

    SELECT  SubIssueTypeId as SubIssueTypeId,   
            CASE WHEN @Langkey = 'zh-CN' THEN SubIssueTypeNameCS ELSE SubIssueTypeName END AS SubIssueTypeName   
    FROM bodb_Account.dbo.TicketVoiding_SubIssueType WITH(NOLOCK) 
    WHERE IssueTypeId = 11
END  