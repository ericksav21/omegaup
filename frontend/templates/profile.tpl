{include file='head.tpl'}

<div style="width: 920px; position: relative; margin: 0 auto 0 auto; ">
    <table>
    <tr>
        <td>
            <div class="post footer" style="width: 130px; min-height: 300px;">
                <img src="https://secure.gravatar.com/avatar/<?php echo md5($this->user->getUsername()); ?>?s=128">
            </div>
        </td>


        <td >
            <div class="post" style="width: 760px; min-height: 300px;">
                <div class="copy" >

                </div>
            </div>
        </td>
    </tr>
    </table>
</div>




{include file='footer.tpl'}
