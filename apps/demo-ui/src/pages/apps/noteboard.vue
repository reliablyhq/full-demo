<template>
    <section class="noteboard">
        <div class="container">
            <form class="form">
                <div class="input-wrapper">
                    <input type="text" name="note" />
                    <button>Send Note</button>
                </div>
            </form>
            <hr />
            <div class="notes">

            </div>
        </div>
    </section>
</template>

<style lang="scss" scoped>
.noteboard {
    display: flex;
    flex-direction: row;
    justify-content: center;
}

</style>